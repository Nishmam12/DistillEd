"""Per-anonymous-device daily caps: LLM token/request usage, and (Loop 3.4)
Web Search query count.

The gateway is stateless with respect to note content (per the Phase 3
privacy model), but a rate limiter needs *some* durable counter to be worth
anything — a tiny SQLite table keyed by a client-generated device key (never
a user identity) is enough. Rejects with a clear error when a cap is
exceeded rather than silently degrading.

LLM usage and search usage are two INDEPENDENT counters (separate tables,
same file) — a chatty LLM day must not block search access, or vice versa.
"""

from __future__ import annotations

import contextlib
import sqlite3
import threading
from dataclasses import dataclass
from datetime import datetime, timezone

_lock = threading.Lock()


class RateLimitExceededError(Exception):
    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


@contextlib.contextmanager
def _transaction(db_path: str):
    # `sqlite3.Connection` as a context manager only commits/rolls back — it
    # does NOT close the connection, which leaks a file handle (and breaks
    # cleanup on Windows, where you can't delete an open file). `closing()`
    # ensures the connection itself is always released too.
    conn = sqlite3.connect(db_path, check_same_thread=False)
    with contextlib.closing(conn), conn:
        yield conn


@dataclass(frozen=True)
class RateLimitConfig:
    db_path: str
    daily_token_cap: int
    daily_request_cap: int
    # Kill switch across ALL device keys. Device keys are client-chosen, so
    # per-key caps alone cannot bound spend — this does.
    global_token_cap: int = 2_000_000
    global_request_cap: int = 5_000


_GLOBAL_KEY = "*"
_MAX_KEY_LEN = 128


def _check_key(device_key: str) -> None:
    if not device_key or len(device_key) > _MAX_KEY_LEN or device_key == _GLOBAL_KEY:
        raise RateLimitExceededError("Invalid device key.")


class RateLimiter:
    def __init__(self, config: RateLimitConfig) -> None:
        self._config = config
        self._init_db()

    def _init_db(self) -> None:
        with _lock, _transaction(self._config.db_path) as conn:
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
        _check_key(device_key)
        today = datetime.now(timezone.utc).date().isoformat()
        c = self._config
        with _lock, _transaction(c.db_path) as conn:
            # IMMEDIATE takes the write lock up front so the check-then-write
            # below is atomic across worker processes too.
            conn.execute("BEGIN IMMEDIATE")
            conn.execute("DELETE FROM usage WHERE day < ?", (today,))

            def used(key: str) -> tuple[int, int]:
                row = conn.execute(
                    "SELECT tokens, requests FROM usage WHERE device_key = ? AND day = ?",
                    (key, today),
                ).fetchone()
                return row if row else (0, 0)

            g_tokens, g_requests = used(_GLOBAL_KEY)
            if (
                g_requests + 1 > c.global_request_cap
                or g_tokens + estimated_tokens > c.global_token_cap
            ):
                raise RateLimitExceededError(
                    "The AI service is at capacity for today. Try again tomorrow."
                )
            tokens_so_far, requests_so_far = used(device_key)
            if requests_so_far + 1 > c.daily_request_cap:
                raise RateLimitExceededError(
                    "Daily request limit reached for this device. Try again tomorrow."
                )
            if tokens_so_far + estimated_tokens > c.daily_token_cap:
                raise RateLimitExceededError(
                    "Daily token limit reached for this device. Try again tomorrow."
                )

            for key in (device_key, _GLOBAL_KEY):
                conn.execute(
                    """
                    INSERT INTO usage (device_key, day, tokens, requests)
                    VALUES (?, ?, ?, 1)
                    ON CONFLICT(device_key, day) DO UPDATE SET
                        tokens = tokens + excluded.tokens,
                        requests = requests + 1
                    """,
                    (key, today, estimated_tokens),
                )


@dataclass(frozen=True)
class SearchRateLimitConfig:
    db_path: str
    daily_search_cap: int
    global_search_cap: int = 500


class SearchRateLimiter:
    """Independent daily cap for the Web Search tool (Loop 3.4) — same
    device-key/day counting discipline as [RateLimiter], its own table so
    LLM and search usage never contend for the same budget.
    """

    def __init__(self, config: SearchRateLimitConfig) -> None:
        self._config = config
        self._init_db()

    def _init_db(self) -> None:
        with _lock, _transaction(self._config.db_path) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS search_usage (
                    device_key TEXT NOT NULL,
                    day TEXT NOT NULL,
                    searches INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (device_key, day)
                )
                """
            )

    def check_and_record(self, device_key: str) -> None:
        """Raises [RateLimitExceededError] if [device_key] already used its
        daily search cap; otherwise records one more search.
        """
        _check_key(device_key)
        today = datetime.now(timezone.utc).date().isoformat()
        c = self._config
        with _lock, _transaction(c.db_path) as conn:
            conn.execute("BEGIN IMMEDIATE")
            conn.execute("DELETE FROM search_usage WHERE day < ?", (today,))

            def used(key: str) -> int:
                row = conn.execute(
                    "SELECT searches FROM search_usage WHERE device_key = ? AND day = ?",
                    (key, today),
                ).fetchone()
                return row[0] if row else 0

            if used(_GLOBAL_KEY) + 1 > c.global_search_cap:
                raise RateLimitExceededError(
                    "Web search is at capacity for today. Try again tomorrow."
                )
            if used(device_key) + 1 > c.daily_search_cap:
                raise RateLimitExceededError(
                    "Daily search limit reached for this device. Try again tomorrow."
                )
            for key in (device_key, _GLOBAL_KEY):
                conn.execute(
                    """
                    INSERT INTO search_usage (device_key, day, searches)
                    VALUES (?, ?, 1)
                    ON CONFLICT(device_key, day) DO UPDATE SET
                        searches = searches + 1
                    """,
                    (key, today),
                )
