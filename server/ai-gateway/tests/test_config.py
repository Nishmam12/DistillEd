"""Settings read the environment when they are built, not when the module loads."""

from app.config import Settings


def test_a_variable_set_after_import_is_seen_by_a_new_settings(monkeypatch):
    monkeypatch.setenv("DAILY_TOKEN_CAP", "1234")
    assert Settings().daily_token_cap == 1234


def test_defaults_apply_when_a_variable_is_unset(monkeypatch):
    monkeypatch.delenv("DAILY_TOKEN_CAP", raising=False)
    assert Settings().daily_token_cap == 200000


def test_numeric_and_float_settings_are_parsed(monkeypatch):
    monkeypatch.setenv("APPROX_COST_PER_1K_TOKENS_USD", "0.25")
    monkeypatch.setenv("TRUSTED_PROXY_HOPS", "1")
    settings = Settings()
    assert settings.approx_cost_per_1k_tokens_usd == 0.25
    assert settings.trusted_proxy_hops == 1
