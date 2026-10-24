"""Margo AI Gateway — a minimal, stateless router to cloud-tier models.

Scope (Phase 3, locked decision): this gateway never stores notes, memory, or
user profiles. It receives a request, forwards it to a model provider,
streams the response back, and forgets it. See
`docs/AI_PIPELINE_PLAN.md` for the full scope boundary.
"""

from __future__ import annotations

import asyncio

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


@app.get("/health")
async def health() -> dict[str, str]:
    # Touches the counter database: a gateway that cannot count usage cannot
    # enforce its caps, so it should not report itself healthy.
    try:
        await asyncio.to_thread(generate._get_rate_limiter().ping)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=503, detail="Rate-limit store unavailable.") from exc
    return {"status": "ok"}
