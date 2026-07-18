"""Common provider shape so routing never depends on a specific vendor SDK.

Every adapter yields plain text chunks — the router/endpoint layer handles
turning that into SSE events, so a new provider never touches the wire
format.
"""

from __future__ import annotations

from typing import AsyncIterator, Protocol


class ChatTurn:
    """One prior turn. Mirrors the Flutter side's `AiMessage` shape."""

    __slots__ = ("role", "content")

    def __init__(self, role: str, content: str) -> None:
        self.role = role
        self.content = content


class ProviderError(Exception):
    """Raised by an adapter when the upstream call fails or errors mid-stream."""


class ModelProvider(Protocol):
    def is_available(self) -> bool:
        """False when this provider's key isn't configured — the router skips it."""
        ...

    def generate(
        self,
        *,
        prompt: str,
        system_prompt: str | None,
        history: list[ChatTurn],
        temperature: float,
        max_tokens: int | None,
    ) -> AsyncIterator[str]:
        """Streams the reply as plain text chunks. Raises `ProviderError` on failure."""
        ...
