# InkFlow AI Integration — Phase 3: Minimal Cloud Gateway + Intelligent Router

You are continuing the AI integration of **InkFlow**. **Phases 0-2 must be complete.** Read `AI_PROGRESS.md` in full first. This is the first phase that introduces a network call and a backend service — treat that as a real architectural boundary, not a casual addition.

## 1. Explicit scope boundary (read this twice)

The original plan document described a full backend with database schema, auth, and cloud note storage. **That is explicitly out of scope here.** The decision that was made for this project:

> Keep the application local-first. Continue using Isar as the primary database and perform as much AI processing as possible on-device using Gemma 4 E2B/E4B. Introduce a minimal FastAPI AI Gateway whose only responsibility is routing requests to larger cloud models (Gemma 26B/31B and optional Gemini, Claude, GPT). Do not introduce cloud note storage, synchronization, or authentication yet. Design the architecture so that Supabase (Postgres, Auth, Storage, pgvector) can be added later without changing the application's core architecture.

Concretely, this means:

- **The gateway is stateless.** It does not store notes, memory, or user profiles. It receives a request (prompt + context the app chose to send), forwards it to a model provider, streams the response back, and forgets it.
- **No user accounts, no login.** If you need to rate-limit or attribute cost, use a device-generated anonymous API key, not a user identity system.
- **The app decides what leaves the device**, per request, with the user able to see and control it (see Loop 3.4). The gateway never pulls data — it only relays what the app sends it, per call.
- Leave clean seams (a `UserContext`/`AuthProvider` interface point in the gateway request pipeline that's currently a no-op) so Supabase Auth/Postgres/pgvector can be dropped in later without a rewrite — but don't build the Supabase integration now.

## 2. Loop plan

### Loop 3.1 — FastAPI AI Gateway skeleton

New top-level directory in the repo: `server/ai-gateway/` (separate from the Flutter app; Python 3.11+, FastAPI, `uvicorn`).

- `app/main.py` — FastAPI app, health check endpoint (`GET /health`).
- `app/routers/generate.py` — `POST /v1/generate`: accepts `{ model_tier: "cloud-mid" | "cloud-frontier", provider_hint?: "gemini"|"claude"|"gpt", prompt, system_prompt?, history?, stream: bool }`, streams tokens back via SSE or chunked response (match whatever the Flutter `AiProvider.generate` stream contract from Phase 0 expects, so the client-side `CloudGatewayProvider` — see Loop 3.3 — is a thin adapter, not a translation layer).
- `app/routers/embed.py` — `POST /v1/embed` (only needed if a cloud embedding model is ever used; otherwise stub/defer — Phase 2's on-device embeddings likely cover this already; don't build it speculatively).
- Config via environment variables (`.env`, never committed — add `server/ai-gateway/.env` to `.gitignore` if not already covered) for provider API keys.
- Basic structured logging (request id, model tier, token count, latency, cost estimate) — no prompt/response content in logs by default (privacy — see section 3).
- Containerize with a `Dockerfile` and note deployment options (Fly.io, Railway, Cloud Run, a small VPS) in the gateway's own README — don't actually deploy as part of this loop, just make it deployable.

### Loop 3.2 — Provider adapters inside the gateway

`server/ai-gateway/app/providers/`:

- `gemma_cloud_provider.py` — routes to Gemma 26B A4B / 31B (via whatever hosted endpoint is current — Vertex AI, a self-hosted inference endpoint, or a third-party host; confirm current availability rather than assuming a specific hosting path, and document the choice).
- `gemini_provider.py`, `claude_provider.py`, `gpt_provider.py` — thin wrappers around each vendor's official SDK. All optional/feature-flagged via env vars — the gateway must run with only the Gemma cloud tier configured and zero frontier keys present.
- Common `ModelProvider` protocol (Python `Protocol` or ABC) so adding a new provider later doesn't touch routing logic.
- **Budget/cost guardrails**: a per-key daily token/request cap (in-memory or simple SQLite counter is fine — this gateway is stateless with respect to user notes, not necessarily storage-free for its own operational needs like rate-limit counters). Reject with a clear error when exceeded rather than silently degrading.

### Loop 3.3 — Client-side Intelligent Router

Back in the Flutter app, `lib/features/ai/domain/routing/`:

- `intelligent_router.dart` — the decision function from the plan doc, now made concrete:
  - Inputs: task type (grammar/rewrite/summarize-page/summarize-notebook/research/thesis-writing/complex-reasoning/large-codebase), estimated context size, network availability (`connectivity_plus` or similar), a user privacy setting (`localOnly` / `askEachTime` / `allowCloudForNonSensitive`), and remaining local budget signals if relevant (e.g. battery — only if trivial to read, don't over-engineer this).
  - Output: which `AiProvider` implementation to use — `LocalGemmaProvider` (Phase 0), or a new `CloudGatewayProvider` (this loop) configured for `cloud-mid` or `cloud-frontier`.
  - Default routing table, matching the plan doc's intent: grammar/rewrite/short-explain → local; notebook summarization/research assistance/study planning → local first, cloud-mid if local context window is insufficient; thesis-writing/complex-reasoning/large-codebase analysis → cloud-frontier, and only when the user's privacy setting allows it.
  - **Never silently send to cloud.** If a task would route to cloud and the privacy setting is `askEachTime` (make this the default), surface a confirmation showing what's about to be sent before the call happens.
- `cloud_gateway_provider.dart implements AiProvider` — calls the FastAPI gateway over HTTPS, handles streaming, handles the gateway being unreachable (fall back to local with a visible notice, don't fail silently or hang).
- Add a visible, persistent indicator whenever a cloud call is in flight or was just used (the plan doc's "clearly indicate when cloud AI is being used" privacy rule) — a small badge in the AI Sidebar is enough, but it must be genuinely noticeable, not buried.

### Loop 3.4 — Tool Calling

- Define a `Tool` interface (`lib/features/ai/domain/tools/tool.dart`) and implement a first useful subset rather than the full plan-doc list: Calculator (pure Dart, no network), Wikipedia lookup (network, cloud-routed tasks only), Web Search (network, cloud-routed only — pick a search API, note the cost). Defer arXiv/YouTube/OCR/Diagram-generator/Citation-manager/Calendar to Phase 4 or later — they're either redundant with Phase 0's PDF handling or genuinely lower priority.
- Wire tool calling through both `LocalGemmaProvider` (if the chosen on-device runtime supports function calling — many small on-device models don't reliably; if not, restrict tool use to cloud-routed requests and say so in `AI_PROGRESS.md`) and `CloudGatewayProvider`.
- Tools that hit the network must go through the same visible-indicator + privacy-setting gate as cloud model calls.

### Loop 3.5 — Streaming polish end-to-end

- Verify streaming works cleanly through the full path: FastAPI SSE → HTTP client in Flutter (e.g. `dio` with streamed response handling) → `CloudGatewayProvider` → UI. Test interruption (user navigates away mid-stream — cancel the request, don't leak a connection) and gateway error mid-stream (partial output should be preserved and marked as incomplete, not discarded).

## 3. Privacy model for this phase

- Nothing leaves the device by default. The very first cloud call the app ever makes should be preceded by an explicit, clear explanation of what's being sent and why (not just a generic permission dialog).
- Log content-free telemetry only server-side (tier used, latency, token counts) unless the user has separately opted into anything more — and this phase doesn't require building an opt-in analytics system, just don't log prompt/response bodies by default.
- The gateway must be safe to run with zero notes data ever touching it if the user never triggers a cloud-tier task.

## 4. Definition of Done for Phase 3

- [ ] FastAPI gateway runs locally, serves `/v1/generate` with streaming, and works with at least the Gemma cloud tier configured.
- [ ] Frontier providers (Gemini/Claude/GPT) are implemented behind feature flags and work when keys are supplied, without being required.
- [ ] Intelligent Router correctly defaults grammar/short tasks to local and only reaches cloud for tasks that genuinely need it, respecting the user's privacy setting every time.
- [ ] No cloud call happens without a visible indicator and (by default) explicit confirmation.
- [ ] At least Calculator + one network tool work end-to-end through tool calling.
- [ ] Streaming survives interruption and mid-stream errors without hanging or crashing the app.
- [ ] Gateway is stateless with respect to note content; documented cost/rate-limit guardrails exist.
- [ ] `AI_PROGRESS.md` updated with actual routing table used, providers wired, and deployment notes; `flutter analyze` clean; gateway has its own test suite (`pytest`) for routing and provider-selection logic.

## 5. Stop conditions

- Before choosing how Gemma 26B/31B is actually hosted (this has real cost/latency implications).
- Before making cloud routing the default for any task category — the bar should be high for moving something out of the local-only default from Phase 1/2.
- Before adding any tool that costs money per call (search APIs) — confirm pricing and expected usage with the user first.

Stop at Definition of Done and report. Phase 4 (`05_phase4_advanced_future.md`) is exploratory and optional — treat it as a menu, not a mandate.
