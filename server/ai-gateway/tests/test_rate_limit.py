import os
import tempfile

import pytest

from app.rate_limit import (
    RateLimitConfig,
    RateLimitExceededError,
    RateLimiter,
    SearchRateLimitConfig,
    SearchRateLimiter,
)


@pytest.fixture
def limiter():
    fd, path = tempfile.mkstemp(suffix=".sqlite3")
    os.close(fd)
    yield RateLimiter(
        RateLimitConfig(db_path=path, daily_token_cap=1000, daily_request_cap=3)
    )
    os.remove(path)


@pytest.fixture
def search_limiter():
    fd, path = tempfile.mkstemp(suffix=".sqlite3")
    os.close(fd)
    yield SearchRateLimiter(SearchRateLimitConfig(db_path=path, daily_search_cap=3))
    os.remove(path)


def test_first_request_succeeds(limiter):
    limiter.check_and_record("device-a", estimated_tokens=100)  # no raise


def test_rejects_once_token_cap_exceeded(limiter):
    limiter.check_and_record("device-a", estimated_tokens=900)
    with pytest.raises(RateLimitExceededError):
        limiter.check_and_record("device-a", estimated_tokens=200)


def test_rejects_once_request_cap_exceeded(limiter):
    limiter.check_and_record("device-a", estimated_tokens=10)
    limiter.check_and_record("device-a", estimated_tokens=10)
    limiter.check_and_record("device-a", estimated_tokens=10)
    with pytest.raises(RateLimitExceededError):
        limiter.check_and_record("device-a", estimated_tokens=10)


def test_devices_are_tracked_independently(limiter):
    limiter.check_and_record("device-a", estimated_tokens=900)
    limiter.check_and_record("device-b", estimated_tokens=900)  # no raise


# --- SearchRateLimiter (Loop 3.4) -------------------------------------------


def test_search_first_request_succeeds(search_limiter):
    search_limiter.check_and_record("device-a")  # no raise


def test_search_rejects_once_cap_exceeded(search_limiter):
    search_limiter.check_and_record("device-a")
    search_limiter.check_and_record("device-a")
    search_limiter.check_and_record("device-a")
    with pytest.raises(RateLimitExceededError):
        search_limiter.check_and_record("device-a")


def test_search_devices_are_tracked_independently(search_limiter):
    search_limiter.check_and_record("device-a")
    search_limiter.check_and_record("device-a")
    search_limiter.check_and_record("device-a")
    search_limiter.check_and_record("device-b")  # no raise


def test_search_and_llm_caps_are_independent(limiter, search_limiter):
    """A device maxing out its LLM cap must not be blocked from searching,
    and vice versa — the whole reason for two separate tables."""
    limiter.check_and_record("device-a", estimated_tokens=1000)
    with pytest.raises(RateLimitExceededError):
        limiter.check_and_record("device-a", estimated_tokens=1)

    search_limiter.check_and_record("device-a")  # no raise
