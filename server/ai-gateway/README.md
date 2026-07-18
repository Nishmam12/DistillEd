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

Pass a non-empty `"tools"` (OpenAI function-calling shape) to enable Loop
3.4 tool calling — requires `"stream": true` and a provider that supports it
(currently only the Gemma cloud tier). The SSE stream then also emits
`data: {"tool_call": {"call_id", "name", "arguments"}}` events; the caller
runs the tool and calls `/v1/generate` again with the result appended to
`history` as a `role: "tool"` turn. The gateway does not orchestrate this
loop itself — it stays stateless/one-shot per call, same as plain text.

`POST /v1/tools/search` (also requires `X-Device-Key`) proxies Exa for the
Web Search tool — `{"query": "..."}` → `{"results": [{"title", "url",
"snippet"}]}`. Needs `EXA_API_KEY`; 503s cleanly without one. Capped at
`DAILY_SEARCH_CAP` (default 25) per device per day, tracked independently
from the LLM token/request cap.

## Tests

```bash
pytest
```

## Configuration

See `.env.example` for the full list. Only `OPENROUTER_API_KEY` is required —
the gateway runs fine with the frontier provider keys (`GEMINI_API_KEY`,
`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`) left blank; requests that hint at an
unconfigured provider fall back to the Gemma cloud tier automatically.
`EXA_API_KEY` is likewise optional — without it, `/v1/tools/search` 503s and
the Flutter app's Calculator/Wikipedia tools still work.

## Deployment

Deployed on **Render** via the repo-root `render.yaml` Blueprint, which builds
this `Dockerfile`. The container binds `$PORT` (Render injects one), falling
back to 8000 for local `docker run`.

**First-time setup (dashboard, one-off):**
1. In the [Render dashboard](https://dashboard.render.com), **New → Blueprint**
   and connect this GitHub repo (authorize Render's GitHub app for the private
   repo; pick the branch you deploy from).
2. Render reads `render.yaml` and creates the `inkflow-ai-gateway` web service.
   It prompts for the two `sync: false` secrets — paste `OPENROUTER_API_KEY`
   (required) and `EXA_API_KEY` (optional, for Web Search).
3. First deploy builds the image and goes live at
   `https://inkflow-ai-gateway.onrender.com` (exact host shown in the
   dashboard). `GET /health` there should return `{"status":"ok"}`.

After that, every push to the deploy branch auto-redeploys. On the free plan
the instance spins down after ~15 min idle, so the first request after a quiet
period pays a few-seconds cold start.

The only required secret is `OPENROUTER_API_KEY`; frontier keys
(`GEMINI_API_KEY`, etc.) and `EXA_API_KEY` can be added later as env vars with
no image rebuild.

### Other hosts

The same `Dockerfile` runs anywhere; alternatives considered but not used:
**Fly.io** (`fly deploy`, cheap always-on), **Railway** (near-zero-config),
**Google Cloud Run** (scale-to-zero, pay-per-request), or a **small VPS**
(cheapest, most manual).
