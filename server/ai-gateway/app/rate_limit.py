"""Per-anonymous-device daily token/request cap.

The gateway is stateless with respect to note content (per the Phase 3
privacy model), but a rate limiter needs *some* durable counter to be worth
anything — a tiny SQLite table keyed by a client-generated device key (never
a user identity) is enough. Rejects with a clear error when a cap is
exceeded rather than silently degrading.
"""

from __future__ import annotations

import contextlib
import sqlite3
import threading
from dataclasses import dataclass
from datetime import date

_lock = threading.Lock()


class RateLimitExceededError(Exception):
    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


@dataclass(frozen=True)
class RateLimitConfig:
    db_path: str
    daily_token_cap: int
    daily_request_cap: int


class RateLimiter:
    def __init__(self, config: RateLimitConfig) -> None:
        self._config = config
        self._init_db()

    @contextlib.contextmanager
    def _transaction(self):
        # `sqlite3.Connection` as a context manager only commits/rolls back —
        # it does NOT close the connection, which leaks a file handle (and
        # breaks cleanup on Windows, where you can't delete an open file).
        # `closing()` ensures the connection itself is always released too.
        conn = sqlite3.connect(self._config.db_path, check_same_thread=False)
        with contextlib.closing(conn), conn:
            yield conn

    def _init_db(self) -> None:
        with _lock, self._transaction() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS usage (
                    device_key TEXT NOT NULL,
                    day TEXT NOT NULL,
                    tokens INTEGER NOT NULL DEFAULT 0,
                    requests INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (device_key, day)
                )
                """
            )

    def check_and_record(self, device_key: str, estimated_tokens: int) -> None:
        """Raises [RateLimitExceededError] if [device_key] is already at its
        daily cap; otherwise records this request's estimated token cost.

        The token estimate is a pre-call approximation (the real count isn't
        known until the model responds) — conservative by design, so a
        request that would clearly blow the budget is rejected before any
        provider call is made.
        """
        today = date.today().isoformat()
        with _lock, self._transaction() as conn:
            row = conn.execute(
                "SELECT tokens, requests FROM usage WHERE device_key = ? AND day = ?",
                (device_key, today),
            ).fetchone()
            tokens_so_far, requests_so_far = row if row else (0, 0)

            if requests_so_far + 1 > self._config.daily_request_cap:
                raise RateLimitExceededError(
                    "Daily request limit reached for this device. Try again tomorrow."
                )
            if tokens_so_far + estimated_tokens > self._config.daily_token_cap:
                raise RateLimitExceededError(
                    "Daily token limit reached for this device. Try again tomorrow."
                )

            conn.execute(
                """
                INSERT INTO usage (device_key, day, tokens, requests)
                VALUES (?, ?, ?, 1)
                ON CONFLICT(device_key, day) DO UPDATE SET
                    tokens = tokens + excluded.tokens,
                    requests = requests + 1
                """,
                (device_key, today, estimated_tokens),
            )
