"""Structured, content-free request logging.

Per the Phase 3 privacy model: prompt/response bodies are never logged by
default. Only operational metadata — enough to debug latency/cost issues,
never enough to reconstruct what a user wrote.
"""

from __future__ import annotations

import hashlib
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
    status: str  # "ok" | "error" | "rate_limited" | "timeout"
    # Short hash of the device key, so one noisy device can be followed in the
    # logs without the key itself being written down.
    device: str = ""
    # Exception class name only, never its message (that can carry request text).
    error_class: str = ""


def log_request(entry: RequestLogEntry) -> None:
    logger.info(json.dumps(asdict(entry)))


def hash_device(device_key: str) -> str:
    return hashlib.sha256(device_key.encode()).hexdigest()[:12]


def approx_cost(tokens: int, per_1k_usd: float) -> float:
    return round(tokens / 1000 * per_1k_usd, 6)


class Stopwatch:
    """Tiny helper so call sites don't hand-roll `time.perf_counter()` math."""

    def __init__(self) -> None:
        self._start = time.perf_counter()

    def elapsed_ms(self) -> int:
        return int((time.perf_counter() - self._start) * 1000)
