"""Common provider shape so routing never depends on a specific vendor SDK.

Every adapter yields plain text chunks — the router/endpoint layer handles
turning that into SSE events, so a new provider never touches the wire
format.
"""

from __future__ import annotations

from typing import AsyncIterator, Protocol


class ChatTurn:
    """One prior turn. Mirrors the Flutter side's `AiMessage` shape.

    [tool_call_id] / [tool_calls] are only ever set for the Loop 3.4 tool
    round-trip (`role == "tool"` / `role == "assistant"` respectively) — every
    other caller leaves them null, so this stays a plain-text turn as before.
    """

    __slots__ = ("role", "content", "tool_call_id", "tool_calls")

    def __init__(
        self,
        role: str,
        content: str,
        *,
        tool_call_id: str | None = None,
        tool_calls: list[dict] | None = None,
    ) -> None:
        self.role = role
        self.content = content
        self.tool_call_id = tool_call_id
        self.tool_calls = tool_calls


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


# `generate_with_tools` (Loop 3.4) is deliberately NOT part of this Protocol.
# Only `GemmaCloudProvider` implements it so far — the frontier adapters are
# still "unconfigured, untested against a live key" stubs, and forcing a tool
# -calling method onto all four providers for one loop's "first useful
# subset" would be scope creep. `routers/generate.py` detects support with a
# plain `hasattr` check and 400s clearly when a request needs tools and the
# selected provider doesn't have them.
