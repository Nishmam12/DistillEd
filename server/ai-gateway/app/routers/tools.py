"""POST /v1/tools/search — Loop 3.4 Web Search tool.

Proxies Exa's search API so `EXA_API_KEY` never reaches the client (same
reasoning as every other provider key in this gateway — see
`providers/gemma_cloud_provider.py`). Enforces its own independent daily cap
(`SearchRateLimiter`) — separate from the LLM token/request cap in
`rate_limit.py`, so a chatty LLM day can't block search access or vice versa.
"""

from __future__ import annotations

import asyncio
import logging
import re
from urllib.parse import urlparse

import httpx
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from ..config import get_settings
from ..rate_limit import (
    InvalidDeviceKeyError,
    RateLimitExceededError,
    SearchRateLimitConfig,
    SearchRateLimiter,
)

router = APIRouter(prefix="/v1/tools")

_log = logging.getLogger(__name__)
_MAX_RESULTS = 5
_SNIPPET_MAX_CHARS = 500


class SearchRequest(BaseModel):
    query: str = Field(min_length=1, max_length=400)


class SearchResult(BaseModel):
    title: str
    url: str
    snippet: str


class SearchResponse(BaseModel):
    results: list[SearchResult]


async def _search_exa(settings, query: str) -> dict:
    """The one outbound call this endpoint makes — isolated in its own
    function (rather than inlined) so tests can monkeypatch exactly this and
    nothing else. Patching `httpx.AsyncClient.post` directly would also catch
    the ASGI test client's own request into this endpoint, since both are
    `AsyncClient` instances."""
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(
            f"{settings.exa_base_url}/search",
            headers={"x-api-key": settings.exa_api_key},
            json={
                "query": query,
                "type": "auto",
                "numResults": _MAX_RESULTS,
                "contents": {"text": {"maxCharacters": _SNIPPET_MAX_CHARS}},
            },
        )
        resp.raise_for_status()
        return resp.json()


_search_rate_limiter: SearchRateLimiter | None = None


def _get_search_rate_limiter() -> SearchRateLimiter:
    global _search_rate_limiter
    if _search_rate_limiter is None:
        settings = get_settings()
        _search_rate_limiter = SearchRateLimiter(
            SearchRateLimitConfig(
                db_path=settings.rate_limit_db_path,
                daily_search_cap=settings.daily_search_cap,
                global_search_cap=settings.global_search_cap,
            )
        )
    return _search_rate_limiter


@router.post("/search", response_model=SearchResponse)
async def search(
    request: SearchRequest,
    x_device_key: str = Header(..., alias="X-Device-Key"),
) -> SearchResponse:
    settings = get_settings()
    if not settings.exa_enabled:
        raise HTTPException(
            status_code=503,
            detail="Web search is not configured.",
        )

    limiter = _get_search_rate_limiter()
    try:
        await asyncio.to_thread(limiter.check_and_record, x_device_key)
    except InvalidDeviceKeyError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RateLimitExceededError as exc:
        raise HTTPException(status_code=429, detail=exc.message) from exc

    try:
        data = await _search_exa(settings, request.query)
        if not isinstance(data, dict):
            raise ValueError("Exa replied with something other than a JSON object")
    except (httpx.HTTPError, ValueError) as exc:  # ValueError: a body that is not JSON
        _log.warning("exa search failed: %s", type(exc).__name__)
        await asyncio.to_thread(limiter.refund, x_device_key)
        raise HTTPException(
            status_code=502, detail="Web search failed. Try again."
        ) from exc

    return SearchResponse(results=_clean_results(data))


_CONTROL_CHARS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
_TITLE_MAX_CHARS = 200


def _clean(text: str, limit: int) -> str:
    return _CONTROL_CHARS.sub("", text).strip()[:limit]


def _clean_results(data: dict) -> list[SearchResult]:
    """What comes back from the web is attacker-controlled text: only http(s)
    links are passed on, and titles and snippets are bounded and stripped of
    control characters. The app fences them as untrusted data before the model
    sees them."""
    results = []
    for item in data.get("results", [])[:_MAX_RESULTS]:
        if not isinstance(item, dict):
            continue
        url = item.get("url")
        if not isinstance(url, str) or urlparse(url).scheme not in ("http", "https"):
            continue
        title = item.get("title")
        text = item.get("text")
        results.append(
            SearchResult(
                title=_clean(title if isinstance(title, str) and title else url,
                             _TITLE_MAX_CHARS),
                url=url[:2000],
                snippet=_clean(text if isinstance(text, str) else "",
                               _SNIPPET_MAX_CHARS),
            )
        )
    return results
