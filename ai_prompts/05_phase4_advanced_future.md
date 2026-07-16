# InkFlow AI Integration — Phase 4: Advanced & Future Capabilities

You are continuing the AI integration of **InkFlow**. **Phases 0-3 must be complete.** Read `AI_PROGRESS.md` in full first.

## 1. How this phase is different

Phases 0-3 were prescriptive because they're load-bearing — everything later depends on them being solid. Phase 4 is a **menu, not a mandate**. These are the plan doc's "Phase 3/4 roadmap" items (multi-agent tutoring, voice, vision, collaboration, plugin marketplace) — genuinely valuable, but speculative enough that building all of them without checking in would be a mistake. Pick one loop at a time, confirm it's still wanted, build it, checkpoint, ask before the next.

Do not start any loop in this file without explicit confirmation from the user that it's the one they want next — unlike Phases 0-3, do not run these sequentially by default.

## 2. Loop menu

### Loop 4.1 — Vision / Whiteboard understanding

The highest-value item on this list given InkFlow's ink-canvas nature. Instead of relying solely on handwriting-to-text recognition (Phase 0), send a rendered snapshot of the page/canvas region directly to a vision-capable model (cloud-frontier tier — Gemini/Claude/GPT vision, routed through the Phase 3 gateway) for cases where recognition confidence is low or the content is inherently visual (diagrams, hand-drawn charts, math notation with complex layout that text recognition mangles).

- Reuse the existing canvas export path (`features/export/canvas_export_service.dart`) to render a page region to an image — don't build a second rendering pipeline.
- Add this as a fallback/supplement in `PageContentExtractor` (Phase 0): when `HandwritingRecognizer` confidence is low, offer "Ask AI to look at this page directly" as an explicit user action (cloud call, so it goes through the Phase 3 privacy gate — never automatic).
- Particularly useful for math: strokes forming equations are notoriously bad for text-based ink recognition; a vision model reading the rendered page directly often does much better.

### Loop 4.2 — Voice Tutor

- Speech-to-text for voice questions (on-device via platform speech APIs where possible — check current Flutter STT package options — falling back to cloud only if needed) feeding into the existing "Ask your notes" RAG flow (Phase 2, Loop 2.3).
- Text-to-speech for tutor responses, using the local model's response (or cloud, per router) piped to a TTS engine.
- Scope this to Q&A first (ask a question about your notes out loud, hear an answer). Full conversational back-and-forth tutoring is a bigger UX project — don't build it in the same loop as basic STT/TTS wiring.

### Loop 4.3 — Multi-Agent Tutoring

- Only pursue this once single-agent tutoring (Phases 1-3) has real usage/feedback — it's easy to build agent orchestration that's impressive in a demo and adds nothing the user actually needed.
- If pursued: specialize prompts/roles (e.g. a "Socratic questioner" agent vs. a "direct explainer" agent) rather than building generic multi-agent infrastructure. Route through the existing `AiProvider`/router — this is a prompting and orchestration pattern on top of Phase 3's plumbing, not a new provider layer.

### Loop 4.4 — Classroom Collaboration / Plugin Marketplace

- These are product decisions with real scope (multi-user sync implies the Supabase layer the earlier phases deliberately deferred; a plugin marketplace implies a stable public API and review/distribution process). Do not start implementation here — if the user wants to pursue either, treat it as a new planning conversation, not a loop to execute from this file. Flag this explicitly rather than guessing at scope.

## 3. Definition of Done

There is no single Definition of Done for this file — each loop has its own, defined when the user picks it. Before starting any loop:

1. Confirm with the user this is the one they want.
2. Write a short loop-specific plan (2-4 sentences: what's being built, what it depends on from earlier phases, what "done" looks like) and get a nod before touching code.
3. Follow the same plan → build → verify → checkpoint discipline as every earlier phase, updating `AI_PROGRESS.md`.

## 4. Stop conditions

- Before starting any loop in this file at all (see above).
- Any time a loop here would require re-opening a decision locked in an earlier phase (e.g. Loop 4.1 needing a vision-capable cloud provider not yet configured in Phase 3) — surface the dependency rather than quietly expanding scope.
