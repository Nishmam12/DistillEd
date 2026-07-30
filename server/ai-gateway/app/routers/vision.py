"""POST /v1/vision — cloud escalation for figures the on-device VLM can't read.

Deliberately unlike `/v1/generate` in three ways, each for a reason:

* **Not streamed.** The caller (`CloudImageTranscriber` → `FigureAnalyzer`)
  parses the reply as one JSON object describing a chart or diagram. A partial
  object is worthless to it, so SSE would add a wire format with no benefit.
* **Image in the body as base64.** Multipart would mean a second content-type
  path through the same rate limiter and logger for no gain; notebook figures
  are small (a page render is tens of KB), and `MAX_IMAGE_BYTES` keeps it that
  way.
* **Vision-only provider selection.** `select_vision_provider` ignores
  `model_tier`, because the app only reaches this endpoint after the local
  model already failed — see that function's docstring.

Privacy: an image reaches this endpoint only when the user enabled cloud AI
*and* the on-device read missed the quality bar. That policy lives in the app
(`FigureAnalyzer._canEscalate`); the gateway just serves what it is sent.
"""

from __future__ import annotations

import base64
import binascii
import uuid

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from ..config import get_settings
from ..logging_config import RequestLogEntry, Stopwatch, log_request
from ..provider_selection import NoVisionProviderError, select_vision_provider
from ..providers.base import ProviderError
from ..rate_limit import RateLimitExceededError
# Imported as a MODULE, not `from .generate import _get_rate_limiter`, so both
# routers resolve the limiter through the same attribute at call time — one
# process-wide daily counter, and one place for a test to substitute it.
from . import generate as generate_router

router = APIRouter(prefix="/v1")

# 8 MB of decoded image. A rasterised notebook page is far under this; anything
# above it is a client bug or an abuse attempt, and we would rather 413 than
# hand a huge payload to a metered upstream API.
MAX_IMAGE_BYTES = 8 * 1024 * 1024

ALLOWED_MIME_TYPES = {"image/png", "image/jpeg", "image/webp"}

# Vision calls are billed per image, not per word, so the word-count estimate
# `/v1/generate` uses does not apply. This is the flat token cost charged
# against the device's daily cap for one figure read — roughly what a
# ~1MP image plus a short JSON reply actually costs on Gemini Flash.
VISION_TOKEN_COST = 1500


class VisionRequest(BaseModel):
    """One image, one prompt, one JSON answer."""

    # Base64 of the raw image file (no `data:` URI prefix).
    image_base64: str
    mime_type: str = "image/png"
    prompt: str
    temperature: float = 0.0
    max_tokens: int | None = Field(default=1536)
    provider_hint: str | None = None


@router.post("/vision")
async def vision(
    request: VisionRequest,
    x_device_key: str = Header(..., alias="X-Device-Key"),
):
    try:
        image_bytes = base64.b64decode(request.image_base64, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise HTTPException(
            status_code=400, detail="image_base64 is not valid base64."
        ) from exc

    if not image_bytes:
        raise HTTPException(status_code=400, detail="image_base64 is empty.")
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Image exceeds {MAX_IMAGE_BYTES // (1024 * 1024)} MB.",
        )
    if request.mime_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported mime_type: {request.mime_type!r}. "
            f"Expected one of {sorted(ALLOWED_MIME_TYPES)}.",
        )

    # Same per-device daily budget as text generation, so a runaway figure loop
    # cannot bypass the cap by using a different endpoint.
    try:
        generate_router._get_rate_limiter().check_and_record(
            x_device_key, VISION_TOKEN_COST
        )
    except RateLimitExceededError as exc:
        raise HTTPException(status_code=429, detail=exc.message) from exc

    settings = get_settings()
    try:
        provider = select_vision_provider(
            settings=settings, provider_hint=request.provider_hint
        )
    except NoVisionProviderError as exc:
        # 503, not 500: the deployment is simply missing a key, and the app
        # treats this as "cloud unavailable" and keeps its local read.
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    request_id = str(uuid.uuid4())
    watch = Stopwatch()
    try:
        text = await provider.describe_image(
            image_bytes=image_bytes,
            mime_type=request.mime_type,
            prompt=request.prompt,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
        )
    except ProviderError as exc:
        log_request(
            RequestLogEntry(
                request_id=request_id,
                model_tier="vision",
                provider=type(provider).__name__,
                token_count=VISION_TOKEN_COST,
                latency_ms=watch.elapsed_ms(),
                approx_cost_usd=0.0,
                status="error",
            )
        )
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    log_request(
        RequestLogEntry(
            request_id=request_id,
            model_tier="vision",
            provider=type(provider).__name__,
            token_count=VISION_TOKEN_COST,
            latency_ms=watch.elapsed_ms(),
            approx_cost_usd=0.0,
            status="ok",
        )
    )
    return {"text": text, "request_id": request_id}
