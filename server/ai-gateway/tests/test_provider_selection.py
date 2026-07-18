"""Provider-selection logic — the thing that actually needs coverage, per the
Phase 3 Definition of Done ("Intelligent Router correctly defaults... and only
reaches cloud for tasks that genuinely need it" is verified client-side; this
covers the gateway's own tier/provider fallback rules).
"""

import pytest

from app.config import Settings
from app.provider_selection import UnknownModelTierError, select_provider
from app.providers.claude_provider import ClaudeProvider
from app.providers.gemma_cloud_provider import GemmaCloudProvider
from app.providers.gpt_provider import GptProvider


def _settings(**overrides) -> Settings:
    base = dict(
        openrouter_api_key="or-key",
        gemini_api_key="",
        anthropic_api_key="",
        openai_api_key="",
    )
    base.update(overrides)
    return Settings(**base)


def test_defaults_to_gemma_cloud_tier_with_no_hint():
    provider = select_provider(settings=_settings(), model_tier="cloud-mid")
    assert isinstance(provider, GemmaCloudProvider)


def test_unavailable_frontier_hint_falls_back_to_gemma():
    # No ANTHROPIC_API_KEY configured — the hint is an optimization, not a
    # hard requirement, so this must not error.
    provider = select_provider(
        settings=_settings(), model_tier="cloud-mid", provider_hint="claude"
    )
    assert isinstance(provider, GemmaCloudProvider)


def test_available_frontier_hint_is_honored():
    provider = select_provider(
        settings=_settings(anthropic_api_key="a-key"),
        model_tier="cloud-mid",
        provider_hint="claude",
    )
    assert isinstance(provider, ClaudeProvider)
    assert provider.is_available()


def test_gpt_hint_honored_when_configured():
    provider = select_provider(
        settings=_settings(openai_api_key="g-key"),
        model_tier="cloud-frontier",
        provider_hint="gpt",
    )
    assert isinstance(provider, GptProvider)


def test_unknown_tier_raises():
    with pytest.raises(UnknownModelTierError):
        select_provider(settings=_settings(), model_tier="not-a-real-tier")


def test_gateway_runs_with_zero_frontier_keys():
    """Per spec: the gateway must run with only the Gemma tier configured."""
    settings = _settings()  # gemini/anthropic/openai all blank
    assert not settings.gemini_enabled
    assert not settings.claude_enabled
    assert not settings.gpt_enabled
    provider = select_provider(settings=settings, model_tier="cloud-mid")
    assert provider.is_available()
