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

    def supports_vision(self) -> bool:
        """Gemini Flash is natively multimodal — see `describe_image`."""
        return self._settings.gemini_enabled

    async def describe_image(
        self,
        *,
        image_bytes: bytes,
        mime_type: str,
        prompt: str,
        temperature: float,
        max_tokens: int | None,
    ) -> str:
        """One-shot image analysis, returning the full reply as a single string.

        NOT streamed, unlike `generate`: the caller (`FigureAnalyzer` on the
        app side) parses this reply as one JSON object, so a partial stream is
        useless to it and would only add a wire format to get wrong.
        """
        if self._client is None:
            raise ProviderError("Gemini is not configured (no GEMINI_API_KEY).")

        contents = [
            types.Content(
                role="user",
                parts=[
                    types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                    types.Part(text=prompt),
                ],
            )
        ]
        config = types.GenerateContentConfig(
            temperature=temperature,
            max_output_tokens=max_tokens,
            # The figure contract is a JSON object; asking the SDK for JSON
            # removes the markdown-fence stripping the app-side parser would
            # otherwise have to do. The parser stays lenient anyway — this is a
            # belt-and-braces improvement, not something it relies on.
            response_mime_type="application/json",
        )

        try:
            response = await self._client.aio.models.generate_content(
                model=_MODEL_ID, contents=contents, config=config
            )
        except Exception as exc:  # noqa: BLE001
            raise ProviderError(f"Gemini vision call failed: {exc}") from exc

        return response.text or ""
