"""Structured, content-free request logging.

Per the Phase 3 privacy model: prompt/response bodies are never logged by
default. Only operational metadata — enough to debug latency/cost issues,
never enough to reconstruct what a user wrote.
"""

from __future__ import annotations

import json
import logging
import sys
import time
from dataclasses import asdict, dataclass

logger = logging.getLogger("ai_gateway")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)


@dataclass(frozen=True)
class RequestLogEntry:
    request_id: str
    model_tier: str
    provider: str
    token_count: int
    latency_ms: int
    approx_cost_usd: float
    status: str  # "ok" | "error" | "rate_limited"


def log_request(entry: RequestLogEntry) -> None:
    logger.info(json.dumps(asdict(entry)))


class Stopwatch:
    """Tiny helper so call sites don't hand-roll `time.perf_counter()` math."""

    def __init__(self) -> None:
        self._start = time.perf_counter()

    def elapsed_ms(self) -> int:
        return int((time.perf_counter() - self._start) * 1000)
