"""POST /v1/vision — request validation, provider selection and error mapping.

No live key is involved: a stub provider stands in for Gemini, exactly as
`test_generate_endpoint.py` does for the text tiers.
"""

from __future__ import annotations

import base64
import os
import tempfile

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.provider_selection import NoVisionProviderError
from app.providers.base import ProviderError
from app.rate_limit import RateLimitConfig, RateLimiter
from app.routers import generate as generate_module
from app.routers import vision as vision_router

PNG = base64.b64encode(b"\x89PNG\r\n\x1a\n fake image bytes").decode()

FIGURE_JSON = (
    '{"kind": "chart", "summary": "A bar chart of revenue by quarter.", '
    '"confidence": 0.9}'
)


class StubVisionProvider:
    def __init__(self, *, reply: str = FIGURE_JSON, error: str | None = None):
        self.reply = reply
        self.error = error
        self.calls: list[dict] = []

    def is_available(self) -> bool:
        return True

    def supports_vision(self) -> bool:
        return True

    async def describe_image(self, **kwargs):
        self.calls.append(kwargs)
        if self.error:
            raise ProviderError(self.error)
        return self.reply


# `Settings` reads its env vars in the dataclass field defaults, which are
# evaluated once at import — so monkeypatching the environment cannot change a
# cap. Both routers resolve the limiter through
# `generate_module._get_rate_limiter`, so substituting that one attribute gives
# each test its own counter with the caps it wants. Mirrors
# `test_generate_endpoint.py::_fresh_rate_limiter`.
@pytest.fixture
def limiter(monkeypatch):
    def _install(*, daily_request_cap: int = 1000, daily_token_cap: int = 100_000):
        fd, path = tempfile.mkstemp(suffix=".sqlite3")
        os.close(fd)
        instance = RateLimiter(
            RateLimitConfig(
                db_path=path,
                daily_token_cap=daily_token_cap,
                daily_request_cap=daily_request_cap,
            )
        )
        monkeypatch.setattr(
            generate_module, "_get_rate_limiter", lambda: instance
        )
        paths.append(path)
        return instance

    paths: list[str] = []
    yield _install
    for path in paths:
        os.remove(path)


@pytest.fixture
def client(limiter):
    limiter()
    return TestClient(app)


def _use(monkeypatch, provider):
    monkeypatch.setattr(
        vision_router, "select_vision_provider", lambda **_: provider
    )
    return provider


def _post(client, **overrides):
    body = {"image_base64": PNG, "mime_type": "image/png", "prompt": "Describe."}
    body.update(overrides)
    return client.post("/v1/vision", json=body, headers={"X-Device-Key": "dev-1"})


def test_returns_the_providers_json_reply(client, monkeypatch):
    stub = _use(monkeypatch, StubVisionProvider())

    response = _post(client)

    assert response.status_code == 200
    assert response.json()["text"] == FIGURE_JSON
    assert response.json()["request_id"]
    # The decoded image — not the base64 — is what reaches the provider.
    assert stub.calls[0]["image_bytes"].startswith(b"\x89PNG")
    assert stub.calls[0]["mime_type"] == "image/png"


def test_rejects_invalid_base64(client, monkeypatch):
    _use(monkeypatch, StubVisionProvider())

    response = _post(client, image_base64="not!valid!base64")

    assert response.status_code == 400


def test_rejects_an_empty_image(client, monkeypatch):
    _use(monkeypatch, StubVisionProvider())
    assert _post(client, image_base64="").status_code == 400


def test_rejects_an_unsupported_mime_type(client, monkeypatch):
    _use(monkeypatch, StubVisionProvider())

    response = _post(client, mime_type="image/gif")

    assert response.status_code == 400
    assert "mime_type" in response.json()["detail"]


def test_rejects_an_oversized_image(client, monkeypatch):
    _use(monkeypatch, StubVisionProvider())
    huge = base64.b64encode(b"x" * (vision_router.MAX_IMAGE_BYTES + 1)).decode()

    assert _post(client, image_base64=huge).status_code == 413


def test_requires_the_device_key(client, monkeypatch):
    _use(monkeypatch, StubVisionProvider())

    response = client.post(
        "/v1/vision", json={"image_base64": PNG, "prompt": "Describe."}
    )

    assert response.status_code == 422


def test_maps_a_provider_failure_to_502(client, monkeypatch):
    _use(monkeypatch, StubVisionProvider(error="upstream exploded"))

    assert _post(client).status_code == 502


def test_no_configured_vision_provider_is_503(client, monkeypatch):
    def raise_none(**_):
        raise NoVisionProviderError("no key")

    monkeypatch.setattr(vision_router, "select_vision_provider", raise_none)

    # 503 (not 500) is what tells the app to keep its on-device read rather
    # than surfacing an error to the student.
    assert _post(client).status_code == 503


def test_vision_calls_count_against_the_daily_cap(limiter, monkeypatch):
    """A figure loop must not be able to dodge the text endpoint's budget."""
    limiter(daily_request_cap=1)
    _use(monkeypatch, StubVisionProvider())
    client = TestClient(app)

    assert _post(client).status_code == 200
    assert _post(client).status_code == 429
