"""Gemma 26B/31B cloud tier via OpenRouter.

Hosting decision (confirmed with Nabil, 2026-07-18): Google hasn't put Gemma 4
on managed Vertex AI yet, so OpenRouter is used instead — one API key, an
OpenAI-compatible chat-completions endpoint, usage-based billing. Always
required; this is the gateway's baseline cloud tier (unlike the frontier
adapters, which are optional).
"""

from __future__ import annotations

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
