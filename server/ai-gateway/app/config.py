"""Environment-driven configuration.

Everything is read from process env vars (populated from `.env` in dev via
`python-dotenv`, or real environment variables in any hosted deployment).
Frontier provider keys are optional — the gateway must run with only the
Gemma cloud tier (OpenRouter) configured, per the Phase 3 spec.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    # Gemma cloud tier — always required, this is the gateway's baseline tier.
    openrouter_api_key: str = os.getenv("OPENROUTER_API_KEY", "")
    openrouter_base_url: str = os.getenv(
        "OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"
    )
    gemma_26b_model_id: str = os.getenv(
        "GEMMA_26B_MODEL_ID", "google/gemma-4-26b-a4b-it"
    )
    gemma_31b_model_id: str = os.getenv(
        "GEMMA_31B_MODEL_ID", "google/gemma-4-31b-it"
    )

    # Frontier providers — optional, feature-flagged by key presence.
    gemini_api_key: str = os.getenv("GEMINI_API_KEY", "")
    anthropic_api_key: str = os.getenv("ANTHROPIC_API_KEY", "")
    openai_api_key: str = os.getenv("OPENAI_API_KEY", "")

    # Rate limiting (per anonymous device key).
    daily_token_cap: int = int(os.getenv("DAILY_TOKEN_CAP", "200000"))
    daily_request_cap: int = int(os.getenv("DAILY_REQUEST_CAP", "500"))
    rate_limit_db_path: str = os.getenv(
        "RATE_LIMIT_DB_PATH", "rate_limit.sqlite3"
    )

    @property
    def gemini_enabled(self) -> bool:
        return bool(self.gemini_api_key)

    @property
    def claude_enabled(self) -> bool:
        return bool(self.anthropic_api_key)

    @property
    def gpt_enabled(self) -> bool:
        return bool(self.openai_api_key)


@lru_cache
def get_settings() -> Settings:
    return Settings()
