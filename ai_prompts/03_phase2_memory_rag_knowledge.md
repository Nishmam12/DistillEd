# InkFlow AI Integration — Phase 2: Learning Memory, RAG, Knowledge Graph, Study Planner

You are continuing the AI integration of **InkFlow**. **Phases 0 and 1 must be complete.** Read `AI_PROGRESS.md` in full first — it has the provider abstraction, on-device model, handwriting pipeline, Context Engine, and the feature set from Phase 1 (Summarize, Explain, Writing Assistant, Quiz, Flashcards). This phase makes the tutor remember things across sessions and lets it reason over a whole notebook (or multiple notebooks) instead of just the current page.

## 1. What this phase is for

Two related but distinct capabilities:

1. **Long-Term Learning Memory** — durable, structured facts about the learner (what they know, what they struggle with, quiz history, preferences), stored locally, that make future AI responses personalized instead of stateless.
2. **RAG (Retrieval-Augmented Generation)** — a way to pull the *relevant* few paragraphs out of a potentially huge notebook instead of stuffing everything into the local model's limited context window. Also powers Knowledge Graph and Study Planner, which both need to reason across many pages at once.

Everything in this phase is still **local-only** — Isar remains the only store, no network calls, no auth. Design the schema so it could sync to Supabase later (stable IDs, clean foreign-key-shaped relations, no reliance on Isar-specific autoincrement semantics for anything that would need to merge across devices) — but do not build the sync itself.

## 2. Loop plan

### Loop 2.1 — Learning Memory schema

New Isar collections under `lib/features/ai/data/memory/` (mirror the existing `NotePage` collection style):

- `ConceptMastery` — `conceptName`, `notebookId`/`pageId` refs, `masteryLevel` (enum: unseen/learning/practiced/mastered), `lastSeenAt`, `timesReviewed`, `timesMissedInQuiz`.
- `QuizAttemptRecord` — links back to a quiz generated in Phase 1, score, per-question correctness, timestamp, concepts covered (so a bad quiz result can decrement `ConceptMastery` for the specific concepts missed, not the whole topic).
- `LearningPreferences` — preferred explain mode (from Phase 1's Explain modes), preferred difficulty, pace signal (derived, not asked — e.g. average time-to-mastery across concepts).
- `StudySession` (optional but useful) — coarse session log: notebook touched, duration, features used. Keep this lightweight; this is not an analytics platform.
- Write a `LearningMemoryRepository` in `lib/features/ai/data/memory/` with the CRUD + a few purpose-built queries the rest of this phase needs: `weakConcepts(notebookId)`, `masteredConcepts(notebookId)`, `dueForReview()` (spaced-repetition-ish: concepts not reviewed in N days, weighted by mastery level — a simple SM-2-lite scheduler is enough, don't build a full spaced-repetition research project here).
- Update `ConceptMastery` automatically from two places: quiz results (Phase 1's quiz flow, now wired to write here) and Context Engine's `knowledgeGaps`/`keyConcepts` output (seeing a concept without testing on it still counts as "learning", not "mastered").

### Loop 2.2 — On-device RAG pipeline

`lib/features/ai/domain/rag/`:

- **Chunking**: `page_chunker.dart` — split `PageContent` (and, for imported PDFs, the extracted text) into overlapping chunks (roughly paragraph-sized, ~200-400 tokens, ~10-15% overlap). Preserve `sourceRef` (notebook/page/position) on every chunk so retrieved results can link back to the original page for "insert as note" / "jump to source" UI later.
- **Embedding**: the Phase 0 `AiProvider.embed()` may still be a stub — this loop needs it real. If the chosen on-device runtime (from Phase 0) doesn't expose embeddings, evaluate a small dedicated embedding model (e.g. a quantized sentence-embedding model runnable via the same on-device inference path, or ONNX Runtime Mobile with a compact model like a distilled MiniLM variant) — confirm current best option before committing, and record the decision + size/latency tradeoffs in `AI_PROGRESS.md`.
- **Vector storage**: Isar does not have native vector search. Options, in order of preference given the "stay on Isar" constraint: (a) store embeddings as `List<double>` on a `NoteChunk` Isar collection and do brute-force cosine similarity in Dart at query time — perfectly fine for a single user's notebook-scale data (thousands, not millions, of chunks) and avoids adding a new storage engine; (b) if brute-force search becomes a measurable performance problem (profile before assuming), consider `objectbox` vector search or `sqlite-vec` as an additive index *alongside* Isar rather than replacing it. Default to (a) unless you have a concrete performance reason not to.
- `rag_retriever.dart` — `Future<List<RetrievedChunk>> retrieve(String query, {int topK = 5, String? notebookId})`.
- Re-chunk/re-embed incrementally when a page changes (hook off the same content-hash-changed signal used in Phase 1's Context Engine caching) — don't re-embed a whole notebook on every keystroke.

### Loop 2.3 — Wire RAG into existing features

- Summarize-notebook (Phase 1, Loop 1.3) and any "ask about my notes" style query should now retrieve relevant chunks via RAG instead of naive concatenation, when content exceeds the context window.
- Add a lightweight "Ask your notes" query box in the AI Sidebar: user asks a question, RAG retrieves top-K chunks across the current notebook, local model answers grounded in those chunks, response shows which pages it drew from (clickable to jump to source).

### Loop 2.4 — Knowledge Graph

- `lib/features/ai/domain/knowledge_graph/` — build a concept graph from `ConceptMastery` entries and the relationships the Context Engine can infer (extend the Context Engine's structured-output prompt from Phase 1 to also emit `relatedConcepts: [{from, to, relation}]` when analyzing a page, rather than building a second separate LLM pass for this).
- Store graph edges in Isar (`ConceptRelation` collection: `fromConcept`, `toConcept`, `relationType`, `notebookId`, `confidence`).
- Simple visualization: a force-directed or hierarchical graph view (a Flutter package like `graphview`, or a custom `CustomPainter` if a maintained package isn't available — check current options) showing concepts colored/sized by `masteryLevel`. This can be a dedicated screen, not embedded in the sidebar.

### Loop 2.5 — Study Planner

- `lib/features/ai/domain/study_planner/` — given `weakConcepts()`, `dueForReview()`, and a user-specified horizon (7/14/30-day, semester, exam countdown with a target date), generate a day-by-day plan: which concepts to review, suggested quiz sessions, suggested new material based on Knowledge Graph gaps (concepts referenced but never studied directly).
- This is a structured-output generation task (local model produces a plan matching a `StudyPlan { days: [{date, focusConcepts, suggestedActivities}] }` schema) refined with the deterministic scheduling data from Loop 2.1/2.4 — don't let the LLM invent the schedule from scratch each time; give it the mastery/due-date data as grounding input so the plan is actually based on real gaps, not generic filler.
- Persist `StudyPlan` in Isar; simple UI to view/regenerate/mark-day-complete.

## 3. Definition of Done for Phase 2

- [ ] `LearningMemoryRepository` persists concept mastery and quiz history, and both Phase 1 quiz results and Context Engine output feed it automatically.
- [ ] RAG retrieval returns relevant, correctly-sourced chunks for a query against a multi-page notebook, and "Ask your notes" works end-to-end offline.
- [ ] Notebook-level summarization uses RAG instead of naive concatenation once content exceeds context window.
- [ ] Knowledge Graph renders real relationships derived from actual notebook content, colored by mastery.
- [ ] Study Planner produces a plan grounded in real weak/due concepts, not generic advice, for at least the 7-day and exam-countdown modes.
- [ ] All storage remains in Isar; schema is documented as "Supabase-sync-ready" (stable IDs, no cross-device assumptions baked in) without actually adding sync.
- [ ] `AI_PROGRESS.md` updated; `flutter analyze` clean; tests cover chunking, retrieval ranking (with a small fixture set where you know the expected top result), and mastery-update logic.

## 4. Stop conditions

- Before picking the embedding model/runtime if Phase 0's provider doesn't already support it.
- If brute-force vector search shows measurable jank on a real device with a realistically-sized notebook — report the numbers before reaching for a heavier dependency.
- Before finalizing the Isar schema for anything you're calling "sync-ready" — confirm the shape makes sense rather than guessing at future Supabase requirements.

Stop at Definition of Done and report. Phase 3 (`04_phase3_cloud_gateway_router.md`) is a separate session and is the first point where any network call is introduced.
