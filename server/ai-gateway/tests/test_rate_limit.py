import os
import tempfile

import pytest

from app.rate_limit import RateLimitConfig, RateLimitExceededError, RateLimiter


@pytest.fixture
def limiter():
    fd, path = tempfile.mkstemp(suffix=".sqlite3")
    os.close(fd)
    yield RateLimiter(
        RateLimitConfig(db_path=path, daily_token_cap=1000, daily_request_cap=3)
    )
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
