"""POST /v1/tools/search — Loop 3.4 Web Search tool.

Proxies Exa's search API so `EXA_API_KEY` never reaches the client (same
reasoning as every other provider key in this gateway — see
`providers/gemma_cloud_provider.py`). Enforces its own independent daily cap
(`SearchRateLimiter`) — separate from the LLM token/request cap in
`rate_limit.py`, so a chatty LLM day can't block search access or vice versa.
"""

from __future__ import annotations

import httpx
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel

from ..config import get_settings
from ..rate_limit import (
    RateLimitExceededError,
    SearchRateLimitConfig,
    SearchRateLimiter,
)

router = APIRouter(prefix="/v1/tools")

_MAX_RESULTS = 5
_SNIPPET_MAX_CHARS = 500


class SearchRequest(BaseModel):
    query: str


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

    try:
        _get_search_rate_limiter().check_and_record(x_device_key)
    except RateLimitExceededError as exc:
        raise HTTPException(status_code=429, detail=exc.message) from exc

    try:
        data = await _search_exa(settings, request.query)
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502, detail=f"Web search failed: {exc}"
        ) from exc

    results = [
        SearchResult(
            title=item.get("title") or item.get("url", ""),
            url=item["url"],
            snippet=(item.get("text") or "").strip(),
        )
        for item in data.get("results", [])[:_MAX_RESULTS]
        if item.get("url")
    ]
    return SearchResponse(results=results)
