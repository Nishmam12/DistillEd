"""Request-shape and abuse guards, kept apart from the routes.

The device key is chosen by the client, so none of these is real identity. They
bound what any one caller can cost: which tools may be declared, how many streams
may run at once, how fast one address may call, and how large a body may be.
"""

from __future__ import annotations

import asyncio
import json
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field

from fastapi import HTTPException, Request

# The tools the app actually ships. Anything else is a client asking the model
# to be handed a function the gateway never meant to expose.
ALLOWED_TOOLS = frozenset({"calculator", "wikipedia", "web_search"})
_MAX_TOOL_DESCRIPTION_CHARS = 1_000
_MAX_TOOL_SCHEMA_CHARS = 4_000
_MAX_TOOL_CALL_JSON_CHARS = 8_000
# What the model may stream back as one tool call's arguments.
MAX_TOOL_ARGUMENT_CHARS = 8_000


def validate_tools(tools: list[dict]) -> None:
    """Raises [ValueError] unless every tool is an allowed OpenAI-shape function."""
    for tool in tools:
        function = tool.get("function") if isinstance(tool, dict) else None
        if (
            not isinstance(function, dict)
            or tool.get("type") != "function"
            or function.get("name") not in ALLOWED_TOOLS
        ):
            raise ValueError(
                f"Unsupported tool. Allowed: {', '.join(sorted(ALLOWED_TOOLS))}."
            )
        description = function.get("description", "")
        parameters = function.get("parameters", {})
        if not isinstance(description, str) or not isinstance(parameters, dict):
            raise ValueError("Malformed tool declaration.")
        if (
            len(description) > _MAX_TOOL_DESCRIPTION_CHARS
            or len(json.dumps(parameters)) > _MAX_TOOL_SCHEMA_CHARS
        ):
            raise ValueError("Tool declaration is too large.")


def validate_history_tool_calls(tool_calls: list[dict] | None) -> None:
    """Raises [ValueError] for a carried-forward tool call that is oversized."""
    if tool_calls and len(json.dumps(tool_calls)) > _MAX_TOOL_CALL_JSON_CHARS:
        raise ValueError("A tool call in the history is too large.")


@dataclass
class _Lease:
    _limiter: "StreamLimiter"
    _device: str
    _released: bool = field(default=False)

    def release(self) -> None:
        """Idempotent: both the stream's own end and the response's cleanup call it."""
        if not self._released:
            self._released = True
            self._limiter._release(self._device)


class StreamLimiter:
    """Caps concurrent model streams, overall and per device key.

    Each open stream holds an upstream connection and a worker; without a cap a
    handful of slow readers could occupy them all.
    """

    def __init__(self, max_total: int = 40, max_per_device: int = 3) -> None:
        self._max_total = max_total
        self._max_per_device = max_per_device
        self._total = 0
        self._per_device: dict[str, int] = defaultdict(int)

    def acquire(self, device_key: str) -> _Lease:
        if (
            self._total >= self._max_total
            or self._per_device[device_key] >= self._max_per_device
        ):
            raise HTTPException(
                status_code=429,
                detail="Too many requests in progress. Try again in a moment.",
            )
        self._total += 1
        self._per_device[device_key] += 1
        return _Lease(self, device_key)

    def _release(self, device_key: str) -> None:
        self._total = max(0, self._total - 1)
        self._per_device[device_key] -= 1
        if self._per_device[device_key] <= 0:
            del self._per_device[device_key]


STREAM_TIMEOUT_SECONDS = 120.0
stream_limiter = StreamLimiter()


def stream_deadline() -> "asyncio.Timeout":
    """Bounds a whole stream, not just the gap between chunks."""
    return asyncio.timeout(STREAM_TIMEOUT_SECONDS)


_MAX_TRACKED_IPS = 10_000


class IpThrottle:
    """Sliding-window calls-per-minute per client address.

    Not durable and per-process, like the rest of the rate limiting here.
    """

    def __init__(self, per_minute: int, trusted_proxy_hops: int = 0) -> None:
        self._per_minute = per_minute
        self._hops = trusted_proxy_hops
        self._calls: dict[str, deque[float]] = {}

    def client_ip(self, request: Request) -> str:
        # The right-most `hops` entries of X-Forwarded-For were added by our own
        # proxies; the one just before them is the caller. Anything further left
        # is whatever the caller claimed.
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded and self._hops > 0:
            parts = [p.strip() for p in forwarded.split(",") if p.strip()]
            if len(parts) >= self._hops:
                return parts[-self._hops]
        return request.client.host if request.client else "unknown"

    def check(self, request: Request) -> None:
        if self._per_minute <= 0:
            return
        now = time.monotonic()
        ip = self.client_ip(request)
        window = self._calls.pop(ip, None) or deque()
        self._calls[ip] = window  # re-insert last: dict order is LRU order
        while window and now - window[0] > 60:
            window.popleft()
        if len(window) >= self._per_minute:
            raise HTTPException(
                status_code=429, detail="Too many requests. Slow down."
            )
        window.append(now)
        while len(self._calls) > _MAX_TRACKED_IPS:  # evict least recently seen
            del self._calls[next(iter(self._calls))]


class BodyLimitMiddleware:
    """Rejects a request body above [max_bytes] before it is parsed.

    Per-field limits still apply, but they only run after the whole body has been
    read; this stops the read. Counts bytes as they arrive, so a chunked upload
    with no Content-Length is stopped too.
    """

    def __init__(self, app, max_bytes: int) -> None:
        self._app = app
        self._max = max_bytes

    async def __call__(self, scope, receive, send) -> None:
        if scope["type"] != "http":
            await self._app(scope, receive, send)
            return

        declared = dict(scope["headers"]).get(b"content-length")
        if declared is not None and declared.isdigit() and int(declared) > self._max:
            await self._reject(send)
            return

        received = 0
        too_big = False

        async def counting_receive():
            nonlocal received, too_big
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self._max:
                    too_big = True
                    return {"type": "http.request", "body": b"", "more_body": False}
            return message

        started = False

        async def guarded_send(message):
            nonlocal started
            if too_big and not started:
                started = True
                await self._reject(send)
                return
            if too_big:
                return
            started = True
            await send(message)

        await self._app(scope, counting_receive, guarded_send)

    @staticmethod
    async def _reject(send) -> None:
        body = b'{"detail":"Request body too large."}'
        await send(
            {
                "type": "http.response.start",
                "status": 413,
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"content-length", str(len(body)).encode()),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})


_IMAGE_MAGIC = {
    "image/png": (b"\x89PNG\r\n\x1a\n",),
    "image/jpeg": (b"\xff\xd8\xff",),
    "image/webp": (b"RIFF",),  # plus "WEBP" at byte 8, checked below
}


def image_matches_mime(data: bytes, mime_type: str) -> bool:
    """Whether [data] starts like the image type it claims to be."""
    prefixes = _IMAGE_MAGIC.get(mime_type)
    if not prefixes or not data.startswith(prefixes):
        return False
    return mime_type != "image/webp" or data[8:12] == b"WEBP"
