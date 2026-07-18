"""Claude frontier tier — optional, feature-flagged by `ANTHROPIC_API_KEY`.

Untested against a live key as of this commit — the gateway runs fine with
this adapter simply unavailable until a key is added.
"""

from __future__ import annotations

from typing import AsyncIterator

from anthropic import AsyncAnthropic

from ..config import Settings
from .base import ChatTurn, ProviderError

_MODEL_ID = "claude-sonnet-5"


class ClaudeProvider:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client = (
            AsyncAnthropic(api_key=settings.anthropic_api_key)
            if settings.claude_enabled
            else None
        )

    def is_available(self) -> bool:
        return self._settings.claude_enabled

    async def generate(
        self,
        *,
        prompt: str,
        system_prompt: str | None,
        history: list[ChatTurn],
        temperature: float,
        max_tokens: int | None,
    ) -> AsyncIterator[str]:
        if self._client is None:
            raise ProviderError("Claude is not configured (no ANTHROPIC_API_KEY).")

        messages = [{"role": turn.role, "content": turn.content} for turn in history]
        messages.append({"role": "user", "content": prompt})

        try:
            async with self._client.messages.stream(
                model=_MODEL_ID,
                system=system_prompt or "",
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens or 1024,
            ) as stream:
                async for text in stream.text_stream:
                    yield text
        except Exception as exc:  # noqa: BLE001
            raise ProviderError(f"Claude call failed: {exc}") from exc
