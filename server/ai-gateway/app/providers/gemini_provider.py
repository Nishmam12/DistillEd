"""Gemini frontier tier — optional, feature-flagged by `GEMINI_API_KEY`.

Uses `google-genai` (the current GA SDK; the older `google-generativeai`
package is deprecated). Untested against a live key as of this commit — the
gateway runs fine with this adapter simply unavailable until a key is added.
"""

from __future__ import annotations

from typing import AsyncIterator

from google import genai
from google.genai import types

from ..config import Settings
from .base import ChatTurn, ProviderError

_MODEL_ID = "gemini-flash-latest"


class GeminiProvider:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client = (
            genai.Client(api_key=settings.gemini_api_key)
            if settings.gemini_enabled
            else None
        )

    def is_available(self) -> bool:
        return self._settings.gemini_enabled

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
            raise ProviderError("Gemini is not configured (no GEMINI_API_KEY).")

        contents = [
            types.Content(
                role="user" if turn.role == "user" else "model",
                parts=[types.Part(text=turn.content)],
            )
            for turn in history
        ]
        contents.append(
            types.Content(role="user", parts=[types.Part(text=prompt)])
        )
        config = types.GenerateContentConfig(
            system_instruction=system_prompt,
            temperature=temperature,
            max_output_tokens=max_tokens,
        )

        try:
            stream = await self._client.aio.models.generate_content_stream(
                model=_MODEL_ID, contents=contents, config=config
            )
            async for chunk in stream:
                if chunk.text:
                    yield chunk.text
        except Exception as exc:  # noqa: BLE001
            raise ProviderError(f"Gemini call failed: {exc}") from exc
