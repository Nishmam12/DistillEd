"""Environment-driven configuration.

Everything is read from process env vars (populated from `.env` in dev via
`python-dotenv`, or real environment variables in any hosted deployment).
Frontier provider keys are optional — the gateway must run with only the
Gemma cloud tier (OpenRouter) configured, per the Phase 3 spec.

Each field reads its variable when a `Settings` is built, not when this module
is imported, so a test (or a process that sets its environment late) sees the
value it set.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from functools import lru_cache

from dotenv import load_dotenv

load_dotenv()


def _env(name: str, default: str) -> str:
    return os.getenv(name, default)


def _env_int(name: str, default: str) -> int:
    return int(os.getenv(name, default))


def _env_float(name: str, default: str) -> float:
    return float(os.getenv(name, default))


@dataclass(frozen=True)
class Settings:
    # Gemma cloud tier — always required, this is the gateway's baseline tier.
    openrouter_api_key: str = field(default_factory=lambda: _env("OPENROUTER_API_KEY", ""))
    openrouter_base_url: str = field(
        default_factory=lambda: _env("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    )
    gemma_26b_model_id: str = field(
        default_factory=lambda: _env("GEMMA_26B_MODEL_ID", "google/gemma-4-26b-a4b-it")
    )
    gemma_31b_model_id: str = field(
        default_factory=lambda: _env("GEMMA_31B_MODEL_ID", "google/gemma-4-31b-it")
    )

    # Frontier providers — optional, feature-flagged by key presence.
    gemini_api_key: str = field(default_factory=lambda: _env("GEMINI_API_KEY", ""))
    anthropic_api_key: str = field(default_factory=lambda: _env("ANTHROPIC_API_KEY", ""))
    openai_api_key: str = field(default_factory=lambda: _env("OPENAI_API_KEY", ""))

    # Web Search tool (Loop 3.4) — optional, feature-flagged by key presence,
    # same pattern as the frontier providers. Pricing/cap confirmed with the
    # product owner on 2026-07-18: Exa standard search, $7/1,000 queries, 25/device/day.
    exa_api_key: str = field(default_factory=lambda: _env("EXA_API_KEY", ""))
    exa_base_url: str = field(default_factory=lambda: _env("EXA_BASE_URL", "https://api.exa.ai"))
    daily_search_cap: int = field(default_factory=lambda: _env_int("DAILY_SEARCH_CAP", "25"))

    # Rate limiting (per anonymous device key).
    daily_token_cap: int = field(default_factory=lambda: _env_int("DAILY_TOKEN_CAP", "200000"))
    daily_request_cap: int = field(default_factory=lambda: _env_int("DAILY_REQUEST_CAP", "500"))
    # Global kill switch across all device keys (see rate_limit.py).
    global_token_cap: int = field(default_factory=lambda: _env_int("GLOBAL_TOKEN_CAP", "2000000"))
    global_request_cap: int = field(default_factory=lambda: _env_int("GLOBAL_REQUEST_CAP", "5000"))
    global_search_cap: int = field(default_factory=lambda: _env_int("GLOBAL_SEARCH_CAP", "500"))
    # Abuse bounds (see guards.py). The device key is client-chosen, so these are
    # about the connection, not the person. 0 turns the per-address throttle off.
    ip_rate_limit_per_minute: int = field(
        default_factory=lambda: _env_int("IP_RATE_LIMIT_PER_MINUTE", "240")
    )
    # Proxies in front of the app that append to X-Forwarded-For (Render: 1).
    # Default 0 = trust no header; X-Forwarded-For is client-forgeable otherwise.
    trusted_proxy_hops: int = field(default_factory=lambda: _env_int("TRUSTED_PROXY_HOPS", "0"))
    max_body_bytes: int = field(
        default_factory=lambda: _env_int("MAX_BODY_BYTES", str(12 * 1024 * 1024))
    )
    # Rough blended price, only for the operational log line.
    approx_cost_per_1k_tokens_usd: float = field(
        default_factory=lambda: _env_float("APPROX_COST_PER_1K_TOKENS_USD", "0.001")
    )
    rate_limit_db_path: str = field(
        default_factory=lambda: _env("RATE_LIMIT_DB_PATH", "rate_limit.sqlite3")
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

    @property
    def exa_enabled(self) -> bool:
        return bool(self.exa_api_key)


@lru_cache
def get_settings() -> Settings:
    return Settings()
