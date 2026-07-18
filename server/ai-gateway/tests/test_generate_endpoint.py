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


class _FakeToolProvider(_FakeProvider):
    """Adds `generate_with_tools` (Loop 3.4) — deliberately NOT on plain
    `_FakeProvider`, so tests can also cover the "provider doesn't support
    tools" 400 path with the existing fake."""

    def __init__(self, events: list[dict], fail_after: int | None = None):
        super().__init__([])
        self._events = events
        self._fail_after = fail_after

    async def generate_with_tools(
        self,
        *,
        prompt: str,
        system_prompt: str | None,
        history: list[ChatTurn],
        temperature: float,
        max_tokens: int | None,
        tools: list[dict],
    ) -> AsyncIterator[dict]:
        for i, event in enumerate(self._events):
            if self._fail_after is not None and i == self._fail_after:
                raise ProviderError("simulated tool provider failure")
            yield event


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


# --- Loop 3.4: tool calling -------------------------------------------------

_A_TOOL = {
    "type": "function",
    "function": {"name": "calculator", "description": "Evaluates math.", "parameters": {}},
}


@pytest.mark.asyncio
async def test_tools_requires_stream_true(client, monkeypatch):
    monkeypatch.setattr(
        generate_module,
        "select_provider",
        lambda **kwargs: _FakeToolProvider([{"text": "unused"}]),
    )
    async with client as c:
        resp = await c.post(
            "/v1/generate",
            headers={"X-Device-Key": "test-device"},
            json={
                "model_tier": "cloud-mid",
                "prompt": "what's 2+2",
                "tools": [_A_TOOL],
                "stream": False,
            },
        )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_tools_rejects_provider_without_tool_support(client, monkeypatch):
    # Plain `_FakeProvider` has no `generate_with_tools` — same as the real
    # Gemini/Claude/GPT adapters this loop.
    monkeypatch.setattr(
        generate_module,
        "select_provider",
        lambda **kwargs: _FakeProvider(["unused"]),
    )
    async with client as c:
        resp = await c.post(
            "/v1/generate",
            headers={"X-Device-Key": "test-device"},
            json={
                "model_tier": "cloud-mid",
                "prompt": "what's 2+2",
                "tools": [_A_TOOL],
                "stream": True,
            },
        )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_tools_streams_text_then_tool_call_event(client, monkeypatch):
    monkeypatch.setattr(
        generate_module,
        "select_provider",
        lambda **kwargs: _FakeToolProvider(
            [
                {"text": "Let me check that. "},
                {
                    "tool_call": {
                        "call_id": "call_1",
                        "name": "calculator",
                        "arguments": {"expression": "2+2"},
                    }
                },
            ]
        ),
    )
    async with client as c:
        async with c.stream(
            "POST",
            "/v1/generate",
            headers={"X-Device-Key": "test-device"},
            json={
                "model_tier": "cloud-mid",
                "prompt": "what's 2+2",
                "tools": [_A_TOOL],
                "stream": True,
            },
        ) as resp:
            assert resp.status_code == 200
            body = b"".join([chunk async for chunk in resp.aiter_bytes()]).decode()
    assert '"text": "Let me check that. "' in body
    assert '"call_id": "call_1"' in body
    assert '"name": "calculator"' in body


@pytest.mark.asyncio
async def test_tools_mid_stream_failure_preserves_partial_output(client, monkeypatch):
    monkeypatch.setattr(
        generate_module,
        "select_provider",
        lambda **kwargs: _FakeToolProvider(
            [{"text": "partial"}, {"text": "never-sent"}], fail_after=1
        ),
    )
    async with client as c:
        async with c.stream(
            "POST",
            "/v1/generate",
            headers={"X-Device-Key": "test-device"},
            json={
                "model_tier": "cloud-mid",
                "prompt": "hi",
                "tools": [_A_TOOL],
                "stream": True,
            },
        ) as resp:
            body = b"".join([chunk async for chunk in resp.aiter_bytes()]).decode()
    assert '"text": "partial"' in body
    assert '"error"' in body
    assert "never-sent" not in body


@pytest.mark.asyncio
async def test_tool_history_turn_round_trips(client, monkeypatch):
    """A `role: "tool"` history turn (the recall step of the client-side
    orchestration loop) must reach the provider intact — this is what makes
    the second `/v1/generate` call in the loop a valid conversation."""
    captured: dict = {}

    class _CapturingProvider(_FakeToolProvider):
        async def generate_with_tools(self, *, history, **kwargs):
            captured["history"] = history
            async for event in super().generate_with_tools(history=history, **kwargs):
                yield event

    monkeypatch.setattr(
        generate_module,
        "select_provider",
        lambda **kwargs: _CapturingProvider([{"text": "It's 4."}]),
    )
    async with client as c:
        async with c.stream(
            "POST",
            "/v1/generate",
            headers={"X-Device-Key": "test-device"},
            json={
                "model_tier": "cloud-mid",
                "prompt": "what's 2+2",
                "tools": [_A_TOOL],
                "stream": True,
                "history": [
                    {"role": "user", "content": "what's 2+2"},
                    {
                        "role": "assistant",
                        "content": "",
                        "tool_calls": [
                            {
                                "id": "call_1",
                                "type": "function",
                                "function": {
                                    "name": "calculator",
                                    "arguments": '{"expression":"2+2"}',
                                },
                            }
                        ],
                    },
                    {"role": "tool", "content": "4", "tool_call_id": "call_1"},
                ],
            },
        ) as resp:
            assert resp.status_code == 200
            _ = b"".join([chunk async for chunk in resp.aiter_bytes()])

    history = captured["history"]
    assert history[1].tool_calls[0]["id"] == "call_1"
    assert history[2].tool_call_id == "call_1"
