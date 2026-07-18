FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

# rate_limit.sqlite3 lives in the working directory by default (see
# app/config.py RATE_LIMIT_DB_PATH) — mount a volume there in production if
# the counter should survive container restarts; it's fine to lose on
# restart otherwise (worst case: caps reset early).
EXPOSE 8000
# Bind $PORT when the host injects one (Render, Cloud Run, etc.); fall back to
# 8000 for local `docker run`. `exec` keeps uvicorn as PID 1 so it still gets
# SIGTERM for a graceful shutdown.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
