# Pinned by digest so a re-tagged base image cannot change what is built. To
# update: `docker pull python:3.11-slim` and take the new digest.
FROM python:3.11-slim@sha256:0dd364ba7e10242f07755449e3a3d0e35f9efd987952737b90def6709ab0c5ce

ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Hash-locked: pip refuses any file whose hash is not in requirements.lock.
# Regenerate with `uv pip compile requirements.txt --generate-hashes
# --python-version 3.11 -o requirements.lock` when requirements.txt changes.
COPY requirements.lock .
RUN pip install --no-cache-dir --require-hashes -r requirements.lock

COPY app/ ./app/

# Run unprivileged. /data is where RATE_LIMIT_DB_PATH should point (mount a
# persistent disk there in production, or caps reset on every restart).
RUN useradd --no-create-home app && mkdir /data && chown app /data /app
USER app

# rate_limit.sqlite3 lives in the working directory by default (see
# app/config.py RATE_LIMIT_DB_PATH) — mount a volume there in production if
# the counter should survive container restarts; it's fine to lose on
# restart otherwise (worst case: caps reset early).
EXPOSE 8000

# /health also touches the rate-limit database, so this fails when the gateway
# can no longer count usage.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/health' % os.environ.get('PORT','8000'), timeout=4)"

# Bind $PORT when the host injects one (Render, Cloud Run, etc.); fall back to
# 8000 for local `docker run`. `exec` keeps uvicorn as PID 1 so it still gets
# SIGTERM for a graceful shutdown.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
