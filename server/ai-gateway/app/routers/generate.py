"""POST /v1/generate — the gateway's one real endpoint.

Streams via SSE by default (`stream: true`, the common case — the Flutter
`CloudGatewayProvider` always requests streaming to match the `AiProvider`
contract's incremental-chunk shape). `stream: false` is supported for
non-Flutter/test callers and returns the full text as plain JSON.

`/v1/embed` is deliberately not built here — Phase 2's on-device
EmbeddingGemma already covers embeddings; see the phase spec.
"""

from __future__ import annotations

import json
import uuid
from typing import Literal

from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from ..config import get_settings
from ..logging_config import RequestLogEntry, Stopwatch, log_request
from ..provider_selection import UnknownModelTierError, select_provider
from ..providers.base import ChatTurn, ProviderError
from ..rate_limit import RateLimitConfig, RateLimiter, RateLimitExceededError

router = APIRouter(prefix="/v1")

# Rough tokens-per-word ratio for the pre-call rate-limit estimate — matches
# the same heuristic the Flutter app's `AiRouter` uses (`tokensPerWord`), kept
# in sync by convention rather than shared code across the two languages.
_TOKENS_PER_WORD = 1.35


class HistoryTurn(BaseModel):
    role: Literal["system", "user", "assistant", "tool"]
    content: str = ""
    # Loop 3.4 tool round-trip only: `tool_call_id` on a `role: "tool"` turn
    # answers a specific prior call; `tool_calls` on a `role: "assistant"`
    # turn carries that call forward (OpenAI-shape `[{"id","type","function":
    # {"name","arguments"}}]`) so a follow-up request's history stays a valid
    # conversation. Both null on every non-tool turn.
    tool_call_id: str | None = None
    tool_calls: list[dict] | None = None


class GenerateRequest(BaseModel):
    model_tier: Literal["cloud-mid", "cloud-frontier"]
    provider_hint: Literal["gemini", "claude", "gpt"] | None = None
    prompt: str
    system_prompt: str | None = None
    history: list[HistoryTurn] = []
    stream: bool = True
    temperature: float = 0.7
    max_tokens: int | None = None
    # Loop 3.4: OpenAI-shape function declarations
    # (`[{"type":"function","function":{"name","description","parameters"}}]`).
    # Empty means "no tools" — every existing caller is unaffected.
    tools: list[dict] = []


def _estimate_tokens(request: GenerateRequest) -> int:
    words = len(request.prompt.split())
    words += sum(len(turn.content.split()) for turn in request.history)
    if request.system_prompt:
        words += len(request.system_prompt.split())
    return int(words * _TOKENS_PER_WORD) + (request.max_tokens or 512)


_rate_limiter: RateLimiter | None = None


def _get_rate_limiter() -> RateLimiter:
    global _rate_limiter
    if _rate_limiter is None:
        settings = get_settings()
        _rate_limiter = RateLimiter(
            RateLimitConfig(
                db_path=settings.rate_limit_db_path,
                daily_token_cap=settings.daily_token_cap,
                daily_request_cap=settings.daily_request_cap,
            )
        )
    return _rate_limiter


@router.post("/generate")
async def generate(
    request: GenerateRequest,
    x_device_key: str = Header(..., alias="X-Device-Key"),
):
    settings = get_settings()
    estimated_tokens = _estimate_tokens(request)

    try:
        _get_rate_limiter().check_and_record(x_device_key, estimated_tokens)
    except RateLimitExceededError as exc:
        raise HTTPException(status_code=429, detail=exc.message) from exc

    try:
        provider = select_provider(
            settings=settings,
            model_tier=request.model_tier,
            provider_hint=request.provider_hint,
        )
    except UnknownModelTierError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    if not provider.is_available():
        raise HTTPException(
            status_code=503,
            detail="No cloud provider is configured for this request.",
        )

    history = [
        ChatTurn(
            role=t.role,
            content=t.content,
            tool_call_id=t.tool_call_id,
            tool_calls=t.tool_calls,
        )
        for t in request.history
    ]
    request_id = str(uuid.uuid4())

    if request.tools:
        # Tool calling (Loop 3.4) is a multi-turn, client-orchestrated flow —
        # only the streaming shape carries a `tool_call` event distinctly
        # from plain text; a non-streaming caller has no way to receive one.
        if not request.stream:
            raise HTTPException(
                status_code=400,
                detail="tools requires stream: true.",
            )
        if not hasattr(provider, "generate_with_tools"):
            raise HTTPException(
                status_code=400,
                detail=f"{type(provider).__name__} does not support tool calling yet.",
            )
        return StreamingResponse(
            _sse_stream_with_tools(
                request_id, request, provider, history, estimated_tokens
            ),
            media_type="text/event-stream",
        )

    if request.stream:
        return StreamingResponse(
            _sse_stream(request_id, request, provider, history, estimated_tokens),
            media_type="text/event-stream",
        )

    watch = Stopwatch()
    try:
        text = "".join(
            [
                chunk
                async for chunk in provider.generate(
                    prompt=request.prompt,
                    system_prompt=request.system_prompt,
                    history=history,
                    temperature=request.temperature,
                    max_tokens=request.max_tokens,
                )
            ]
        )
    except ProviderError as exc:
        log_request(
            RequestLogEntry(
                request_id=request_id,
                model_tier=request.model_tier,
                provider=type(provider).__name__,
                token_count=estimated_tokens,
                latency_ms=watch.elapsed_ms(),
                approx_cost_usd=0.0,
                status="error",
            )
        )
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    log_request(
        RequestLogEntry(
            request_id=request_id,
            model_tier=request.model_tier,
            provider=type(provider).__name__,
            token_count=estimated_tokens,
            latency_ms=watch.elapsed_ms(),
            approx_cost_usd=0.0,
            status="ok",
        )
    )
    return {"text": text, "request_id": request_id}


async def _sse_stream(request_id, request, provider, history, estimated_tokens):
    watch = Stopwatch()
    status = "ok"
    try:
        async for chunk in provider.generate(
            prompt=request.prompt,
            system_prompt=request.system_prompt,
            history=history,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
        ):
            yield f"data: {json.dumps({'text': chunk})}\n\n"
    except ProviderError as exc:
        status = "error"
        # Partial output already reached the client via prior `data:` events —
        # this final error event lets `CloudGatewayProvider` mark the reply
        # incomplete rather than silently truncating it.
        yield f"data: {json.dumps({'error': str(exc)})}\n\n"
    finally:
        log_request(
            RequestLogEntry(
                request_id=request_id,
                model_tier=request.model_tier,
                provider=type(provider).__name__,
                token_count=estimated_tokens,
                latency_ms=watch.elapsed_ms(),
                approx_cost_usd=0.0,
                status=status,
            )
        )


async def _sse_stream_with_tools(
    request_id, request, provider, history, estimated_tokens
):
    """Loop 3.4 variant of [_sse_stream]: also emits `tool_call` events.

    One gateway call is still exactly one model round-trip (the gateway stays
    stateless) — the app is the one that decides to run a tool and call this
    endpoint again with the result appended to `history`; this generator just
    needs to pass `tool_call` events through instead of only `text`.
    """
    watch = Stopwatch()
    status = "ok"
    try:
        async for event in provider.generate_with_tools(
            prompt=request.prompt,
            system_prompt=request.system_prompt,
            history=history,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
            tools=request.tools,
        ):
            yield f"data: {json.dumps(event)}\n\n"
    except ProviderError as exc:
        status = "error"
        yield f"data: {json.dumps({'error': str(exc)})}\n\n"
    finally:
        log_request(
            RequestLogEntry(
                request_id=request_id,
                model_tier=request.model_tier,
                provider=type(provider).__name__,
                token_count=estimated_tokens,
                latency_ms=watch.elapsed_ms(),
                approx_cost_usd=0.0,
                status=status,
            )
        )
