# How to Use These Prompts (Loop Engineering Method)

This folder contains a sequence of implementation prompts for turning InkFlow (the existing Flutter ink-notebook app) into the AI-powered learning workspace described in `AI_Notebook_Master_Plan.md`. They are written for **Claude Fable** (or any strong coding agent) and designed to be run **one phase at a time, in order**.

## Why "loop engineering"

A single giant prompt that asks for the whole architecture at once produces broad, shallow, untested code, and the agent loses track of its own state across context resets. Instead, each phase file below turns the agent into a bounded **plan → build → verify → checkpoint** loop:

1. **Plan** — the agent reads `AI_PROGRESS.md`, restates what already exists, and proposes the next vertical slice (one feature, end-to-end, not a whole layer).
2. **Build** — implement only that slice, following the existing InkFlow architecture conventions (feature-based `domain/data/presentation`, Riverpod, get_it).
3. **Verify** — run `flutter analyze`, run/extend tests with `flutter test`, and manually confirm the acceptance criteria for that slice.
4. **Checkpoint** — update `AI_PROGRESS.md` with what was built, what was decided, what's deferred, and commit. Only then does the agent start the next loop iteration.

The agent should never try to finish an entire phase in one uninterrupted pass. It stops at the end of each loop, reports status, and either continues automatically (if you told it to) or waits for your go-ahead — your call, set at the top of each session.

## Files, in order

| # | File | Covers |
|---|------|--------|
| 0 | `01_phase0_foundation.md` | AI provider abstraction, on-device Gemma runtime, handwriting-to-text pipeline (strokes → recognized text), shared `ai_core` module scaffolding |
| 1 | `02_phase1_context_engine_core_features.md` | Live Context Engine, AI Sidebar, Summarize, Explain, Writing Assistant, Flashcards, Quiz Generator (all on-device) |
| 2 | `03_phase2_memory_rag_knowledge.md` | Long-Term Learning Memory, on-device RAG, Knowledge Graph, Study Planner |
| 3 | `04_phase3_cloud_gateway_router.md` | Minimal FastAPI AI Gateway, Intelligent Router, cloud Gemma tiers, optional Gemini/Claude/GPT, Tool Calling |
| 4 | `05_phase4_advanced_future.md` | Voice Tutor, Vision/Whiteboard understanding, multi-agent tutoring, collaboration — exploratory, lower priority |

Each file is self-contained: it re-states the project identity and hard constraints so it works even if you start a fresh Claude Fable session per phase (recommended — don't try to carry one session across all five files, the context will bloat).

## Before you run Phase 0

1. `AI_Notebook_Master_Plan.md` (your original plan doc) is already in this folder so the agent can `Read` it directly instead of relying on a pasted summary.
2. Create an empty `AI_PROGRESS.md` at the repo root (template below). The agent reads and writes this file every loop — it's the memory that survives context resets and session restarts.
3. Open a fresh Claude Fable session, paste in `01_phase0_foundation.md` verbatim, and let it run.

## `AI_PROGRESS.md` starter template

```markdown
# AI Integration Progress Log

## Current Phase
Phase 0 — Foundation (not started)

## Decisions Locked In
- Local-first: Isar remains the only on-device store; no cloud sync/auth yet.
- On-device models: Gemma 4 E2B/E4B via on-device inference (package TBD in Phase 0).
- Cloud tier: minimal FastAPI gateway only, added in Phase 3, no note data leaves device without explicit user action.
- Platform: Android only for now (no ios/ directory exists yet).

## Completed Slices
(none yet)

## Deferred / Open Questions
(none yet)

## Next Loop
Start Phase 0, Loop 1: provider abstraction interface.
```

## Ground rules that apply to every phase (don't repeat yourself — the agent should internalize these once)

- **Never rewrite the existing editor.** Canvas, stroke input, undo/redo, PDF import, shapes, and page storage are done. AI code observes and reads from them; it does not modify `features/editor/presentation/canvas/**` or `features/editor/domain/undo_redo/**` except to add read-only hooks explicitly called out in a phase file.
- **Match existing conventions**: feature folders under `lib/features/<feature>/{domain,data,presentation}`, Riverpod `Notifier`/`AsyncNotifier` for state, `get_it` for service location, Isar `@collection` models with generated `.g.dart` parts, go_router for navigation.
- **Every new dependency needs a one-line justification** in `AI_PROGRESS.md` before it's added to `pubspec.yaml`.
- **Test as you go.** New services get unit tests under `test/features/ai/...` mirroring `lib/features/ai/...`, following the existing `mocktail`-based test style already used in `test/features/editor/...`.
- **Ask before irreversible or expensive decisions**: picking the on-device model runtime package, adding a native platform channel, standing up the FastAPI gateway, or spending real API credits on a frontier model call.
