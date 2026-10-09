"""InkFlow AI Gateway — a minimal, stateless router to cloud-tier models.

Scope (Phase 3, locked decision): this gateway never stores notes, memory, or
user profiles. It receives a request, forwards it to a model provider,
streams the response back, and forgets it. See
`ai_prompts/04_phase3_cloud_gateway_router.md` for the full scope boundary.
"""

from __future__ import annotations

from fastapi import Depends, FastAPI, HTTPException, Request

from .config import get_settings
from .guards import BodyLimitMiddleware, IpThrottle
from .routers import generate, tools, vision

_settings = get_settings()
_throttle = IpThrottle(
    _settings.ip_rate_limit_per_minute, _settings.trusted_proxy_hops
)


def _throttle_by_ip(request: Request) -> None:
    if request.url.path != "/health":  # the host's own probe is not a caller
        _throttle.check(request)


app = FastAPI(
    title="InkFlow AI Gateway",
    version="0.1.0",
    dependencies=[Depends(_throttle_by_ip)],
)
app.add_middleware(BodyLimitMiddleware, max_bytes=_settings.max_body_bytes)
app.include_router(generate.router)
app.include_router(tools.router)
app.include_router(vision.router)


@app.get("/health")
async def health() -> dict[str, str]:
    # Touches the counter database: a gateway that cannot count usage cannot
    # enforce its caps, so it should not report itself healthy.
    try:
        generate._get_rate_limiter().ping()
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=503, detail="Rate-limit store unavailable.") from exc
    return {"status": "ok"}
