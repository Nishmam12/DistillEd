"""Gemma 26B/31B cloud tier via OpenRouter.

Hosting decision (confirmed with Nabil, 2026-07-18): Google hasn't put Gemma 4
on managed Vertex AI yet, so OpenRouter is used instead — one API key, an
OpenAI-compatible chat-completions endpoint, usage-based billing. Always
required; this is the gateway's baseline cloud tier (unlike the frontier
adapters, which are optional).
"""

from __future__ import annotations

import json
from typing import AsyncIterator

from openai import AsyncOpenAI

from ..config import Settings
from .base import ChatTurn, ProviderError

_TIER_TO_MODEL = {
    "cloud-mid": "gemma_26b_model_id",
    "cloud-frontier": "gemma_31b_model_id",
}


class GemmaCloudProvider:
    def __init__(self, settings: Settings, model_tier: str = "cloud-mid") -> None:
        self._settings = settings
        self._model_id = getattr(settings, _TIER_TO_MODEL.get(model_tier, "gemma_26b_model_id"))
        self._client = AsyncOpenAI(
            api_key=settings.openrouter_api_key or "unset",
            base_url=settings.openrouter_base_url,
        )

    def is_available(self) -> bool:
        return bool(self._settings.openrouter_api_key)

    async def generate(
        self,
        *,
        prompt: str,
        system_prompt: str | None,
        history: list[ChatTurn],
        temperature: float,
        max_tokens: int | None,
    ) -> AsyncIterator[str]:
        messages: list[dict[str, str]] = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        for turn in history:
            messages.append({"role": turn.role, "content": turn.content})
        messages.append({"role": "user", "content": prompt})

        try:
            stream = await self._client.chat.completions.create(
                model=self._model_id,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=True,
            )
            async for chunk in stream:
                delta = chunk.choices[0].delta.content if chunk.choices else None
                if delta:
                    yield delta
        except Exception as exc:  # noqa: BLE001 — any SDK/network failure maps the same way
            raise ProviderError(f"Gemma cloud tier failed: {exc}") from exc

    async def generate_with_tools(
        self,
        *,
        prompt: str,
        system_prompt: str | None,
        history: list[ChatTurn],
        temperature: float,
        max_tokens: int | None,
        tools: list[dict],
    ) -> AsyncIterator[dict]:
        """Tool-calling variant of [generate] (Loop 3.4).

        Yields `{"text": "..."}` chunks as they stream, then one
        `{"tool_call": {"call_id", "name", "arguments"}}` event per call the
        model requested, once the stream ends. OpenAI's streaming format
        fragments each tool call's `arguments` JSON across several chunks,
        keyed by `index` — accumulated here rather than parsed per-fragment,
        since a partial JSON string isn't parseable until it's complete.
        """
        messages: list[dict] = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        for turn in history:
            msg: dict = {"role": turn.role, "content": turn.content}
            if turn.role == "tool" and turn.tool_call_id:
                msg["tool_call_id"] = turn.tool_call_id
            if turn.role == "assistant" and turn.tool_calls:
                msg["tool_calls"] = turn.tool_calls
            messages.append(msg)
        if prompt:
            # A hop past the first has nothing new from the *user* — the new
            # turn is the tool result already appended above (`role: "tool"`)
            # — so there is nothing to append here. Forcing an empty
            # `{"role": "user", "content": ""}` onto the end would be an
            # invalid trailing turn for a tool-result conversation.
            messages.append({"role": "user", "content": prompt})

        try:
            stream = await self._client.chat.completions.create(
                model=self._model_id,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                tools=tools,
                tool_choice="auto",
                stream=True,
            )
            # Keyed by the delta's `index`, not `id` — the SDK only sends
            # `id`/`function.name` on a call's FIRST fragment; `arguments`
            # arrives incrementally across subsequent fragments at the same
            # index and must be concatenated before it's valid JSON.
            pending: dict[int, dict] = {}
            async for chunk in stream:
                if not chunk.choices:
                    continue
                delta = chunk.choices[0].delta
                if delta.content:
                    yield {"text": delta.content}
                for tc in delta.tool_calls or []:
                    slot = pending.setdefault(
                        tc.index, {"id": None, "name": None, "arguments": ""}
                    )
                    if tc.id:
                        slot["id"] = tc.id
                    if tc.function and tc.function.name:
                        slot["name"] = tc.function.name
                    if tc.function and tc.function.arguments:
                        slot["arguments"] += tc.function.arguments

            for slot in pending.values():
                if not slot["id"] or not slot["name"]:
                    raise ProviderError("Model produced an incomplete tool call.")
                try:
                    arguments = json.loads(slot["arguments"] or "{}")
                except json.JSONDecodeError as exc:
                    raise ProviderError(
                        "Model produced a malformed tool call."
                    ) from exc
                yield {
                    "tool_call": {
                        "call_id": slot["id"],
                        "name": slot["name"],
                        "arguments": arguments,
                    }
                }
        except ProviderError:
            raise
        except Exception as exc:  # noqa: BLE001
            raise ProviderError(f"Gemma cloud tier failed: {exc}") from exc
