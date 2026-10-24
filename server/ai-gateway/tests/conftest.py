import pytest


@pytest.fixture(autouse=True)
def _fresh_health_cache(monkeypatch):
    # /health caches its probe result; every test starts with no cached answer.
    from app import main

    monkeypatch.setattr(main, "_health_checked_at", float("-inf"))
    monkeypatch.setattr(main, "_health_ok", False)
