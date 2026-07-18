"""GPT frontier tier — optional, feature-flagged by `OPENAI_API_KEY`.

Untested against a live key as of this commit — the gateway runs fine with
this adapter simply unavailable until a key is added. Model id is
configurable via env so it can be bumped without a code change as OpenAI
ships newer models.
"""

from __future__ import annotations

import os
from typing import AsyncIterator

from openai import AsyncOpenAI

from ..config import Settings
from .base import ChatTurn, ProviderError

_MODEL_ID = os.getenv("GPT_MODEL_ID", "gpt-5")


class GptProvider:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client = (
            AsyncOpenAI(api_key=settings.openai_api_key)
            if settings.gpt_enabled
            else None
        )

    def is_available(self) -> bool:
        return self._settings.gpt_enabled

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
            raise ProviderError("GPT is not configured (no OPENAI_API_KEY).")

        messages: list[dict[str, str]] = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        for turn in history:
            messages.append({"role": turn.role, "content": turn.content})
        messages.append({"role": "user", "content": prompt})

        try:
            stream = await self._client.chat.completions.create(
                model=_MODEL_ID,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=True,
            )
            async for chunk in stream:
                delta = chunk.choices[0].delta.content if chunk.choices else None
                if delta:
                    yield delta
        except Exception as exc:  # noqa: BLE001
            raise ProviderError(f"GPT call failed: {exc}") from exc
