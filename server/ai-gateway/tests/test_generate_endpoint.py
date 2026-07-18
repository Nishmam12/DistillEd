import os
import tempfile
from typing import AsyncIterator

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.providers.base import ChatTurn, ProviderError
from app.rate_limit import RateLimitConfig, RateLimiter
from app.routers import generate as generate_module


class _FakeProvider:
    """Duck-types `ModelProvider` without any real SDK/network call."""

    def __init__(self, chunks: list[str], fail_after: int | None = None):
        self._chunks = chunks
        self._fail_after = fail_after

    def is_available(self) -> bool:
        return True

    async def generate(
        self,
        *,
        prompt: str,
        system_prompt: str | None,
        history: list[ChatTurn],
        temperature: float,
        max_tokens: int | None,
    ) -> AsyncIterator[str]:
        for i, chunk in enumerate(self._chunks):
            if self._fail_after is not None and i == self._fail_after:
                raise ProviderError("simulated provider failure")
            yield chunk


@pytest.fixture(autouse=True)
def _fresh_rate_limiter(monkeypatch):
    """Isolates each test's rate-limit counter to its own temp SQLite file —
    otherwise the module-level singleton would share state (and create a
    stray file) across the whole test session."""
    fd, path = tempfile.mkstemp(suffix=".sqlite3")
    os.close(fd)
    limiter = RateLimiter(
        RateLimitConfig(db_path=path, daily_token_cap=100_000, daily_request_cap=1000)
    )
    monkeypatch.setattr(generate_module, "_get_rate_limiter", lambda: limiter)
    yield
    os.remove(path)


@pytest.fixture
def client():
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")


@pytest.mark.asyncio
async def test_health_check(client):
    async with client as c:
        resp = await c.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_generate_requires_device_key_header(client):
    async with client as c:
        resp = await c.post(
            "/v1/generate",
            json={"model_tier": "cloud-mid", "prompt": "hi"},
        )
    assert resp.status_code == 422  # missing required header


@pytest.mark.asyncio
async def test_non_streaming_generate_returns_full_text(client, monkeypatch):
    monkeypatch.setattr(
        generate_module,
        "select_provider",
        lambda **kwargs: _FakeProvider(["Hello", " world"]),
    )
    async with client as c:
        resp = await c.post(
            "/v1/generate",
            headers={"X-Device-Key": "test-device"},
            json={
                "model_tier": "cloud-mid",
                "prompt": "hi",
                "stream": False,
            },
        )
    assert resp.status_code == 200
    body = resp.json()
    assert body["text"] == "Hello world"
    assert "request_id" in body


@pytest.mark.asyncio
async def test_streaming_generate_emits_sse_chunks(client, monkeypatch):
    monkeypatch.setattr(
        generate_module,
        "select_provider",
        lambda **kwargs: _FakeProvider(["chunk-one", "chunk-two"]),
    )
    async with client as c:
        async with c.stream(
            "POST",
            "/v1/generate",
            headers={"X-Device-Key": "test-device"},
            json={"model_tier": "cloud-mid", "prompt": "hi", "stream": True},
        ) as resp:
            assert resp.status_code == 200
            body = b"".join([chunk async for chunk in resp.aiter_bytes()]).decode()
    assert '"text": "chunk-one"' in body
    assert '"text": "chunk-two"' in body


@pytest.mark.asyncio
async def test_mid_stream_failure_preserves_partial_output(client, monkeypatch):
    monkeypatch.setattr(
        generate_module,
        "select_provider",
        lambda **kwargs: _FakeProvider(["partial", "never-sent"], fail_after=1),
    )
    async with client as c:
        async with c.stream(
            "POST",
            "/v1/generate",
            headers={"X-Device-Key": "test-device"},
            json={"model_tier": "cloud-mid", "prompt": "hi", "stream": True},
        ) as resp:
            body = b"".join([chunk async for chunk in resp.aiter_bytes()]).decode()
    assert '"text": "partial"' in body
    assert '"error"' in body
    assert "never-sent" not in body
