"""Picks which `ModelProvider` serves a request.

Kept separate from `routers/generate.py` so the selection logic (the thing
that actually needs test coverage) doesn't require spinning up FastAPI to
exercise it.
"""

from __future__ import annotations

from .config import Settings
from .providers.base import ModelProvider
from .providers.claude_provider import ClaudeProvider
from .providers.gemini_provider import GeminiProvider
from .providers.gemma_cloud_provider import GemmaCloudProvider
from .providers.gpt_provider import GptProvider

VALID_TIERS = {"cloud-mid", "cloud-frontier"}
VALID_HINTS = {"gemini", "claude", "gpt"}


class UnknownModelTierError(Exception):
    pass


def select_provider(
    *,
    settings: Settings,
    model_tier: str,
    provider_hint: str | None = None,
) -> ModelProvider:
    """Chooses a provider for [model_tier], honoring [provider_hint] when given.

    A [provider_hint] naming an unavailable (no key) or unknown frontier
    provider falls back to the Gemma cloud tier rather than erroring — the
    hint is an optimization, not a hard requirement.
    """
    if model_tier not in VALID_TIERS:
        raise UnknownModelTierError(f"Unknown model_tier: {model_tier!r}")

    if provider_hint in VALID_HINTS:
        candidate = _FRONTIER_FACTORIES[provider_hint](settings)
        if candidate.is_available():
            return candidate

    return GemmaCloudProvider(settings, model_tier=model_tier)


_FRONTIER_FACTORIES = {
    "gemini": GeminiProvider,
    "claude": ClaudeProvider,
    "gpt": GptProvider,
}
