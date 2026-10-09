"""Tests for POST /v1/tools/search (Loop 3.4 Web Search tool proxy)."""

import json
import os
import tempfile

import httpx
import pytest
from httpx import ASGITransport, AsyncClient

from app.config import Settings
from app.main import app
from app.rate_limit import SearchRateLimitConfig, SearchRateLimiter
from app.routers import tools as tools_module


async def _fake_search_exa(settings, query: str) -> dict:
    return {
        "results": [
            {
                "title": "Ada Lovelace",
                "url": "https://en.wikipedia.org/wiki/Ada_Lovelace",
                "text": "Ada Lovelace was an English mathematician.",
            },
            # No url — the router must drop this one rather than 500.
            {"title": "no url", "url": None, "text": "..."},
        ]
    }


async def _fake_search_exa_error(settings, query: str) -> dict:
    raise httpx.ConnectError("simulated network failure")


def _configured_settings() -> Settings:
    return Settings(exa_api_key="test-exa-key", daily_search_cap=25)


@pytest.fixture(autouse=True)
def _fresh_search_rate_limiter(monkeypatch):
    """Isolates each test's search-cap counter — same reasoning as the LLM
    rate limiter's fixture in `test_generate_endpoint.py`."""
    fd, path = tempfile.mkstemp(suffix=".sqlite3")
    os.close(fd)
    limiter = SearchRateLimiter(
        SearchRateLimitConfig(db_path=path, daily_search_cap=25)
    )
    monkeypatch.setattr(tools_module, "_get_search_rate_limiter", lambda: limiter)
    yield
    os.remove(path)


@pytest.fixture
def client():
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")


@pytest.mark.asyncio
async def test_search_requires_device_key_header(client, monkeypatch):
    monkeypatch.setattr(tools_module, "get_settings", _configured_settings)
    async with client as c:
        resp = await c.post("/v1/tools/search", json={"query": "ada lovelace"})
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_search_503_when_unconfigured(client, monkeypatch):
    monkeypatch.setattr(tools_module, "get_settings", lambda: Settings(exa_api_key=""))
    async with client as c:
        resp = await c.post(
            "/v1/tools/search",
            headers={"X-Device-Key": "test-device"},
            json={"query": "ada lovelace"},
        )
    assert resp.status_code == 503


@pytest.mark.asyncio
async def test_search_returns_mapped_results(client, monkeypatch):
    monkeypatch.setattr(tools_module, "get_settings", _configured_settings)
    monkeypatch.setattr(tools_module, "_search_exa", _fake_search_exa)
    async with client as c:
        resp = await c.post(
            "/v1/tools/search",
            headers={"X-Device-Key": "test-device"},
            json={"query": "ada lovelace"},
        )
    assert resp.status_code == 200
    body = resp.json()
    # The url-less result is dropped; only the real one survives.
    assert len(body["results"]) == 1
    assert body["results"][0]["title"] == "Ada Lovelace"
    assert body["results"][0]["url"] == "https://en.wikipedia.org/wiki/Ada_Lovelace"
    assert "mathematician" in body["results"][0]["snippet"]


@pytest.mark.asyncio
async def test_search_maps_upstream_failure_to_502(client, monkeypatch):
    monkeypatch.setattr(tools_module, "get_settings", _configured_settings)
    monkeypatch.setattr(tools_module, "_search_exa", _fake_search_exa_error)
    async with client as c:
        resp = await c.post(
            "/v1/tools/search",
            headers={"X-Device-Key": "test-device"},
            json={"query": "ada lovelace"},
        )
    assert resp.status_code == 502


@pytest.mark.asyncio
async def test_search_enforces_daily_cap(client, monkeypatch):
    monkeypatch.setattr(tools_module, "get_settings", _configured_settings)
    monkeypatch.setattr(tools_module, "_search_exa", _fake_search_exa)
    fd, path = tempfile.mkstemp(suffix=".sqlite3")
    os.close(fd)
    limiter = SearchRateLimiter(
        SearchRateLimitConfig(db_path=path, daily_search_cap=1)
    )
    monkeypatch.setattr(tools_module, "_get_search_rate_limiter", lambda: limiter)
    try:
        async with client as c:
            first = await c.post(
                "/v1/tools/search",
                headers={"X-Device-Key": "test-device"},
                json={"query": "one"},
            )
            second = await c.post(
                "/v1/tools/search",
                headers={"X-Device-Key": "test-device"},
                json={"query": "two"},
            )
        assert first.status_code == 200
        assert second.status_code == 429
    finally:
        os.remove(path)


@pytest.mark.asyncio
async def test_search_devices_are_tracked_independently(client, monkeypatch):
    monkeypatch.setattr(tools_module, "get_settings", _configured_settings)
    monkeypatch.setattr(tools_module, "_search_exa", _fake_search_exa)
    fd, path = tempfile.mkstemp(suffix=".sqlite3")
    os.close(fd)
    limiter = SearchRateLimiter(
        SearchRateLimitConfig(db_path=path, daily_search_cap=1)
    )
    monkeypatch.setattr(tools_module, "_get_search_rate_limiter", lambda: limiter)
    try:
        async with client as c:
            a = await c.post(
                "/v1/tools/search",
                headers={"X-Device-Key": "device-a"},
                json={"query": "one"},
            )
            b = await c.post(
                "/v1/tools/search",
                headers={"X-Device-Key": "device-b"},
                json={"query": "one"},
            )
        assert a.status_code == 200
        assert b.status_code == 200
    finally:
        os.remove(path)


@pytest.mark.asyncio
async def test_failed_search_is_refunded(client, monkeypatch):
    monkeypatch.setattr(tools_module, "get_settings", _configured_settings)
    monkeypatch.setattr(tools_module, "_search_exa", _fake_search_exa_error)
    fd, path = tempfile.mkstemp(suffix=".sqlite3")
    os.close(fd)
    limiter = SearchRateLimiter(
        SearchRateLimitConfig(db_path=path, daily_search_cap=1)
    )
    monkeypatch.setattr(tools_module, "_get_search_rate_limiter", lambda: limiter)
    try:
        async with client as c:
            for _ in range(2):  # a cap of 1 would 429 the second if not refunded
                resp = await c.post(
                    "/v1/tools/search",
                    headers={"X-Device-Key": "test-device"},
                    json={"query": "x"},
                )
                assert resp.status_code == 502
    finally:
        os.remove(path)


async def _fake_search_exa_not_json(settings, query: str):
    # What `resp.json()` raises when Exa answers with a body that is not JSON.
    raise json.JSONDecodeError("Expecting value", "", 0)


async def _fake_search_exa_not_an_object(settings, query: str):
    return ["not", "the", "results", "object"]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "fake", [_fake_search_exa_not_json, _fake_search_exa_not_an_object]
)
async def test_malformed_upstream_reply_is_a_502_and_refunded(
    client, monkeypatch, fake
):
    monkeypatch.setattr(tools_module, "get_settings", _configured_settings)
    monkeypatch.setattr(tools_module, "_search_exa", fake)
    fd, path = tempfile.mkstemp(suffix=".sqlite3")
    os.close(fd)
    limiter = SearchRateLimiter(
        SearchRateLimitConfig(db_path=path, daily_search_cap=1)
    )
    monkeypatch.setattr(tools_module, "_get_search_rate_limiter", lambda: limiter)
    try:
        async with client as c:
            for _ in range(2):  # a cap of 1 would 429 the second if not refunded
                resp = await c.post(
                    "/v1/tools/search",
                    headers={"X-Device-Key": "test-device"},
                    json={"query": "x"},
                )
                assert resp.status_code == 502
    finally:
        os.remove(path)


async def _fake_search_exa_with_a_junk_entry(settings, query: str):
    return {
        "results": [
            "junk, not an object",
            {
                "title": "Ada Lovelace",
                "url": "https://en.wikipedia.org/wiki/Ada_Lovelace",
                "text": "Ada Lovelace was an English mathematician.",
            },
        ]
    }


@pytest.mark.asyncio
async def test_a_junk_entry_is_skipped_and_the_rest_still_returned(client, monkeypatch):
    monkeypatch.setattr(tools_module, "get_settings", _configured_settings)
    monkeypatch.setattr(tools_module, "_search_exa", _fake_search_exa_with_a_junk_entry)
    async with client as c:
        resp = await c.post(
            "/v1/tools/search",
            headers={"X-Device-Key": "test-device"},
            json={"query": "ada lovelace"},
        )
    assert resp.status_code == 200
    assert [r["title"] for r in resp.json()["results"]] == ["Ada Lovelace"]

