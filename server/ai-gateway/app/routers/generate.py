"""POST /v1/generate — the gateway's one real endpoint.

Streams via SSE by default (`stream: true`, the common case — the Flutter
`CloudGatewayProvider` always requests streaming to match the `AiProvider`
contract's incremental-chunk shape). `stream: false` is supported for
non-Flutter/test callers and returns the full text as plain JSON.

`/v1/embed` is deliberately not built here — Phase 2's on-device
EmbeddingGemma already covers embeddings; see the phase spec.
"""

from __future__ import annotations

import asyncio
import json
import logging
import uuid
from typing import Literal

from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field, field_validator
from starlette.background import BackgroundTask

from ..config import get_settings
from ..guards import (
    stream_deadline,
    stream_limiter,
    validate_history_tool_calls,
    validate_tools,
)
from ..logging_config import (
    RequestLogEntry,
    Stopwatch,
    approx_cost,
    hash_device,
    log_request,
)
from ..provider_selection import UnknownModelTierError, select_provider
from ..providers.base import ChatTurn, ProviderError
from ..rate_limit import (
    InvalidDeviceKeyError,
    RateLimitConfig,
    RateLimiter,
    RateLimitExceededError,
)

router = APIRouter(prefix="/v1")
_log = logging.getLogger(__name__)

# Rough tokens-per-word ratio for the pre-call rate-limit estimate — matches
# the same heuristic the Flutter app's `AiRouter` uses (`tokensPerWord`), kept
# in sync by convention rather than shared code across the two languages.
_TOKENS_PER_WORD = 1.35

# Input bounds. Without them one request can carry megabytes of text that the
# word-count estimate under-counts, bypassing the token cap.
_MAX_TEXT_CHARS = 60_000
_MAX_HISTORY_TURNS = 40
_MAX_TOOLS = 8
_MAX_OUTPUT_TOKENS = 8192
_DEFAULT_OUTPUT_TOKENS = 1024


class HistoryTurn(BaseModel):
    # No "system": the one system prompt is `system_prompt`. A client-supplied
    # system turn in the middle of a conversation is an injection route.
    role: Literal["user", "assistant", "tool"]
    content: str = Field(default="", max_length=_MAX_TEXT_CHARS)
    # Loop 3.4 tool round-trip only: `tool_call_id` on a `role: "tool"` turn
    # answers a specific prior call; `tool_calls` on a `role: "assistant"`
    # turn carries that call forward (OpenAI-shape `[{"id","type","function":
    # {"name","arguments"}}]`) so a follow-up request's history stays a valid
    # conversation. Both null on every non-tool turn.
    tool_call_id: str | None = Field(default=None, max_length=200)
    tool_calls: list[dict] | None = None

    @field_validator("tool_calls")
    @classmethod
    def _tool_calls_bounded(cls, value):
        try:
            validate_history_tool_calls(value)
        except ValueError as exc:
            raise ValueError(str(exc)) from exc
        return value


class GenerateRequest(BaseModel):
    model_tier: Literal["cloud-mid", "cloud-frontier"]
    provider_hint: Literal["gemini", "claude", "gpt"] | None = None
    prompt: str = Field(max_length=_MAX_TEXT_CHARS)
    system_prompt: str | None = Field(default=None, max_length=_MAX_TEXT_CHARS)
    history: list[HistoryTurn] = Field(default=[], max_length=_MAX_HISTORY_TURNS)
    stream: bool = True
    temperature: float = Field(default=0.7, ge=0, le=2)
    max_tokens: int = Field(default=_DEFAULT_OUTPUT_TOKENS, ge=1, le=_MAX_OUTPUT_TOKENS)
    # Loop 3.4: OpenAI-shape function declarations
    # (`[{"type":"function","function":{"name","description","parameters"}}]`).
    # Empty means "no tools" — every existing caller is unaffected.
    tools: list[dict] = Field(default=[], max_length=_MAX_TOOLS)

    @field_validator("tools")
    @classmethod
    def _tools_allowed(cls, value):
        validate_tools(value)
        return value


def _estimate_tokens(request: GenerateRequest) -> int:
    # Characters, not words: a blob with no whitespace is one "word".
    chars = len(request.prompt) + len(request.system_prompt or "")
    chars += sum(len(turn.content) for turn in request.history)
    return max(int(chars / 4), int(len(request.prompt.split()) * _TOKENS_PER_WORD)) + request.max_tokens


# Upstream exception text can carry URLs and request ids; keep it server-side.
_UPSTREAM_ERROR = "The AI provider failed. Try again."

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
                global_token_cap=settings.global_token_cap,
                global_request_cap=settings.global_request_cap,
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
    # Everything that can be refused for the deployment's own reasons is checked
    # BEFORE the caller is charged: a 503 or 400 must not cost them quota.
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

    limiter = _get_rate_limiter()
    try:
        await asyncio.to_thread(limiter.check_and_record, x_device_key, estimated_tokens)
    except InvalidDeviceKeyError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RateLimitExceededError as exc:
        raise HTTPException(status_code=429, detail=exc.message) from exc

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

    if request.stream:
        try:
            lease = stream_limiter.acquire(x_device_key)
        except HTTPException:
            await asyncio.to_thread(limiter.refund, x_device_key, estimated_tokens)
            raise
        events = (
            _sse_stream_with_tools(
                request_id, request, provider, history, estimated_tokens,
                x_device_key, limiter, lease,
            )
            if request.tools
            else _sse_stream(
                request_id, request, provider, history, estimated_tokens,
                x_device_key, limiter, lease,
            )
        )
        # The generator releases the lease when it ends; this covers a response
        # that is cancelled before the generator ever starts.
        return StreamingResponse(
            events,
            media_type="text/event-stream",
            background=BackgroundTask(lease.release),
        )

    watch = Stopwatch()
    try:
        async with stream_deadline():
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
    except (ProviderError, TimeoutError) as exc:
        _log.warning("provider error: %s", type(exc).__name__)
        # No usable reply, so no charge.
        await asyncio.to_thread(limiter.refund, x_device_key, estimated_tokens)
        _log_done(request_id, request, provider, estimated_tokens, watch,
                  x_device_key, "error", exc)
        raise HTTPException(status_code=502, detail=_UPSTREAM_ERROR) from exc

    _log_done(request_id, request, provider, estimated_tokens, watch,
              x_device_key, "ok", None)
    return {"text": text, "request_id": request_id}


def _log_done(request_id, request, provider, estimated_tokens, watch, device_key,
              status, exc) -> None:
    log_request(
        RequestLogEntry(
            request_id=request_id,
            model_tier=request.model_tier,
            provider=type(provider).__name__,
            token_count=estimated_tokens,
            latency_ms=watch.elapsed_ms(),
            approx_cost_usd=approx_cost(
                estimated_tokens, get_settings().approx_cost_per_1k_tokens_usd
            ),
            status=status,
            device=hash_device(device_key),
            error_class=type(exc).__name__ if exc else "",
        )
    )


async def _stream_events(source, request_id, request, provider, estimated_tokens,
                         device_key, limiter, lease):
    """Shared SSE loop: yields `data:` lines for each event [source] produces.

    [source] is an async iterator of events (`{"text": …}` and friends). The whole
    stream is bounded in time; the lease is always released; and a stream that
    failed before any output refunds the charge.
    """
    watch = Stopwatch()
    status = "ok"
    failure: Exception | None = None
    produced = False
    try:
        async with stream_deadline():
            async for event in source:
                produced = True
                yield f"data: {json.dumps(event)}\n\n"
    except (ProviderError, TimeoutError) as exc:
        _log.warning("provider error: %s", type(exc).__name__)
        failure = exc
        status = "timeout" if isinstance(exc, TimeoutError) else "error"
        # Partial output already reached the client via prior `data:` events —
        # this final error event lets `CloudGatewayProvider` mark the reply
        # incomplete rather than silently truncating it.
        yield f"data: {json.dumps({'error': _UPSTREAM_ERROR})}\n\n"
    finally:
        lease.release()
        if failure is not None and not produced:
            await asyncio.to_thread(limiter.refund, device_key, estimated_tokens)
        _log_done(request_id, request, provider, estimated_tokens, watch,
                  device_key, status, failure)


async def _sse_stream(request_id, request, provider, history, estimated_tokens,
                      device_key, limiter, lease):
    async def source():
        async for chunk in provider.generate(
            prompt=request.prompt,
            system_prompt=request.system_prompt,
            history=history,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
        ):
            yield {"text": chunk}

    async for line in _stream_events(source(), request_id, request, provider,
                                     estimated_tokens, device_key, limiter, lease):
        yield line


async def _sse_stream_with_tools(request_id, request, provider, history,
                                 estimated_tokens, device_key, limiter, lease):
    """Loop 3.4 variant of [_sse_stream]: also emits `tool_call` events.

    One gateway call is still exactly one model round-trip (the gateway stays
    stateless) — the app is the one that decides to run a tool and call this
    endpoint again with the result appended to `history`; this generator just
    needs to pass `tool_call` events through instead of only `text`.
    """
    async for line in _stream_events(
        provider.generate_with_tools(
            prompt=request.prompt,
            system_prompt=request.system_prompt,
            history=history,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
            tools=request.tools,
        ),
        request_id, request, provider, estimated_tokens, device_key, limiter, lease,
    ):
        yield line
