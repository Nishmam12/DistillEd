"""Margo AI Gateway — a minimal, stateless router to cloud-tier models.

Scope (Phase 3, locked decision): this gateway never stores notes, memory, or
user profiles. It receives a request, forwards it to a model provider,
streams the response back, and forgets it. See
`docs/AI_PIPELINE_PLAN.md` for the full scope boundary.
"""

from __future__ import annotations

import asyncio
import time

from fastapi import FastAPI, HTTPException

from .config import get_settings
from .guards import BodyLimitMiddleware, IpThrottle, IpThrottleMiddleware
from .routers import generate, tools, vision

_settings = get_settings()
_throttle = IpThrottle(
    _settings.ip_rate_limit_per_minute, _settings.trusted_proxy_hops
)


app = FastAPI(
    title="Margo AI Gateway",
    version="0.1.0",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)
app.add_middleware(BodyLimitMiddleware, max_bytes=_settings.max_body_bytes)
# Added last, so outermost: a throttled caller is refused before any body is read.
app.add_middleware(IpThrottleMiddleware, throttle=_throttle)
app.include_router(generate.router)
app.include_router(tools.router)
app.include_router(vision.router)


_HEALTH_CACHE_SECONDS = 10.0
_health_checked_at = float("-inf")
_health_ok = False


@app.get("/health")
async def health() -> dict[str, str]:
    # Touches the counter database: a gateway that cannot count usage cannot
    # enforce its caps, so it should not report itself healthy. The answer is
    # cached for a few seconds so probes do not queue behind metered requests
    # for the database lock.
    global _health_checked_at, _health_ok
    if time.monotonic() - _health_checked_at > _HEALTH_CACHE_SECONDS:
        _health_checked_at = time.monotonic()  # set first: one probe per window
        try:
            await asyncio.to_thread(generate._get_rate_limiter().ping)
            _health_ok = True
        except Exception:  # noqa: BLE001
            _health_ok = False
    if not _health_ok:
        raise HTTPException(status_code=503, detail="Rate-limit store unavailable.")
    return {"status": "ok"}
