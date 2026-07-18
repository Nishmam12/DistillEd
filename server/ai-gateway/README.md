# InkFlow AI Gateway

A minimal, stateless FastAPI service whose only job is routing requests to
cloud-tier models. It never stores notes, memory, or user profiles — see
`ai_prompts/04_phase3_cloud_gateway_router.md` in the main repo for the full
scope decision and privacy model.

## Local development

```bash
cd server/ai-gateway
python -m venv .venv
source .venv/bin/activate   # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
cp .env.example .env        # then fill in OPENROUTER_API_KEY at minimum
uvicorn app.main:app --reload
```

`GET /health` → `{"status": "ok"}`.

`POST /v1/generate` (requires an `X-Device-Key` header — any client-generated
UUID, used only for the rate-limit counter, never a user identity):

```bash
curl -N -X POST http://localhost:8000/v1/generate \
  -H "Content-Type: application/json" \
  -H "X-Device-Key: test-device" \
  -d '{"model_tier": "cloud-mid", "prompt": "Say hello in three words."}'
```

Streams Server-Sent Events (`data: {"text": "..."}`); pass `"stream": false`
for a single JSON `{"text": "...", "request_id": "..."}` response instead.

## Tests

```bash
pytest
```

## Configuration

See `.env.example` for the full list. Only `OPENROUTER_API_KEY` is required —
the gateway runs fine with the frontier provider keys (`GEMINI_API_KEY`,
`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`) left blank; requests that hint at an
unconfigured provider fall back to the Gemma cloud tier automatically.

## Deployment (not done yet — this loop only makes it deployable)

The `Dockerfile` builds a standard ASGI container (`uvicorn`, port 8000).
Reasonable hosting options, none picked yet:

- **Fly.io** — simple `fly deploy` from the Dockerfile, cheap always-on
  small instances, good for a low-traffic gateway like this.
- **Railway** — near-zero-config Docker deploy, generous free tier for early
  testing.
- **Google Cloud Run** — pay-per-request (scales to zero when idle), a
  natural fit given the Gemma tier is Google's own model family, though
  that's not currently required since the Gemma tier goes through
  OpenRouter rather than Vertex AI.
- **A small VPS** — cheapest for predictable low traffic, most manual
  maintenance (TLS, restarts, updates).

Whichever is chosen, the only required secret is `OPENROUTER_API_KEY`; the
frontier keys can be added later without a redeploy of the image itself
(env-var only).
