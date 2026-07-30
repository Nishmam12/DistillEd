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


class NoVisionProviderError(Exception):
    """No configured provider can read an image."""


def select_vision_provider(
    *,
    settings: Settings,
    provider_hint: str | None = None,
) -> ModelProvider:
    """Chooses a provider for `/v1/vision`.

    Vision is NOT tiered the way text is. The app only ever calls this endpoint
    after its on-device VLM has already read the figure and missed the quality
    bar, so the request is by definition a hard one — there is no cheap tier
    worth trying first, and `GemmaCloudProvider` (OpenRouter text completions)
    has no image path at all.

    Gemini is the default because it is the multimodal adapter that is actually
    wired here; a [provider_hint] can override it, and an unavailable hint
    falls through to whatever else is configured rather than failing.
    """
    ordered = ["gemini", "claude", "gpt"]
    if provider_hint in VALID_HINTS:
        ordered = [provider_hint] + [h for h in ordered if h != provider_hint]

    for name in ordered:
        candidate = _FRONTIER_FACTORIES[name](settings)
        if getattr(candidate, "supports_vision", lambda: False)():
            return candidate

    raise NoVisionProviderError(
        "No vision-capable provider is configured. Set GEMINI_API_KEY to "
        "enable cloud figure analysis."
    )


_FRONTIER_FACTORIES = {
    "gemini": GeminiProvider,
    "claude": ClaudeProvider,
    "gpt": GptProvider,
}
