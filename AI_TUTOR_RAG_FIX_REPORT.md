# AI tutor / RAG fix — implementation report

Eight workstreams (A–H) against the on-device AI tutor and its RAG pipeline.

**Verification at the end of the work:** `flutter analyze` → *No issues found*.
`flutter test` → **1381 passed, 0 failed** (baseline before the work: 1221 passed,
analyzer clean — so 160 tests were added and none regressed).

---

## 1. The structural picture

The single most consequential change is Workstream C, and it needed a data-model
change that D and E then build on:

- **`NotePage.importGroupId` / `importSourceName`** — pages that arrived from one
  PDF import now carry a shared, indexed identifier. Without it, "the whole PDF"
  is not a thing the app can name, and a 40-page lecture is just 40 loose pages.
- **`AiScope` / `AiScopeResolver`** (`lib/features/ai/domain/ai_scope.dart`) —
  one definition of "this page / this PDF / the whole notebook", resolved once to
  a concrete page-id list and then carried as data. Ask, Summarize, Explain and
  the Knowledge Graph all scope through it, so none of them can mean different
  things by "this PDF".
- **`BulkRagIndexer`** (`lib/features/ai/domain/rag/bulk_indexer.dart`) — the
  second indexing trigger, for pages nobody has opened.

Three other shared pieces were extracted because the same thing had been
rediscovered in several files:

- **`tutor_voice.dart`** — one voice definition, previously three divergent
  copies (Explainer, NotesQa, SummarizationService).
- **`quality/`** — one accuracy fail-safe, rather than four per-feature copies.
- **`math_markup.dart` + `math_text.dart`** — one LaTeX convention and one
  renderer.

---

## 2. Files changed and added

### Added — domain (pure, unit-tested, no Isar/Flutter)
| File | What it is |
|---|---|
| `lib/features/ai/domain/ai_scope.dart` | `AiScopeKind`, `AiScope`, `AiScopeResolver` — the scope model |
| `lib/features/ai/domain/rag/bulk_indexer.dart` | `BulkRagIndexer` — indexes pages nobody opened |
| `lib/features/ai/domain/tutor_voice.dart` | `kTutorVoice`, `kMathMarkup` — shared register + maths convention |
| `lib/features/ai/domain/math_markup.dart` | `parseMathSegments`, `mathAsPlainText` — the `$…$` reader |
| `lib/features/ai/domain/quality/output_quality.dart` | `checkOutputQuality` — the broken-output detector |
| `lib/features/ai/domain/quality/ai_quality_guard.dart` | `AiQualityGuard` — run local → check → escalate |
| `lib/features/ai/domain/chat_commands.dart` | `parseChatCommand` — `/cloud on|off` and natural phrasing |

### Added — presentation
| File | What it is |
|---|---|
| `lib/features/ai/presentation/notebook_index_notifier.dart` | Drives a bulk indexing run |
| `lib/features/ai/presentation/widgets/ai_scope_picker.dart` | The shared "what to search" control |
| `lib/features/ai/presentation/widgets/math_text.dart` | `MathText` / `MathLabel` |
| `lib/features/ai/presentation/widgets/answer_tier_banner.dart` | Cloud badge / low-confidence warning |

### Modified
| File | Why |
|---|---|
| `lib/features/home/domain/models/note_page.dart` (+ `.g.dart`) | Import-group fields |
| `lib/features/home/data/repositories/page_repository.dart` | `tagImport`, `pagesInImportGroup` |
| `lib/features/ai/data/memory/concept_relation_record.dart` (+ `.g.dart`) | `lastPageId`, for page-scoped graphs |
| `lib/features/ai/data/memory/learning_memory_repository.dart` | `conceptsForPages`, `relationsForPages` |
| `lib/features/ai/domain/rag/rag_retriever.dart` | `pageIds` filter on `search` |
| `lib/features/ai/domain/features/notes_qa.dart` | `scope` on `findSources`; prompt rewrite; `promptFor` / `answerOptions` / `qualityContextFor`; release-safe empty-sources refusal |
| `lib/features/ai/domain/features/explainer.dart` | Prompt rewrite; `promptFor` / `explainOptions` |
| `lib/features/ai/domain/context_engine/context_engine.dart` | Maths convention; `schemaInstruction` made public; guard on first attempt |
| `lib/features/summarize/domain/services/summarization_service.dart` | `ImportGroupScope`; prompt rewrite; public prompt constants; guard + `tier` |
| `lib/features/ai/presentation/ai_providers.dart` | `bulkRagIndexerProvider`, `notebookIndexProvider`, `aiScopeResolverProvider`, `aiQualityGuardProvider`; `knowledgeGraphProvider` now keyed by scope |
| `lib/features/ai/presentation/ask_notes_notifier.dart` | Scope, guard, tier, `/cloud` command, `verifyWithCloud` |
| `lib/features/ai/presentation/explain_notifier.dart` | Guard, tier, `verifyWithCloud` |
| `lib/features/ai/presentation/sidebar/ai_sidebar.dart` | `CloudModelToggle` in the header; `importGroup` summarize choice |
| `lib/features/ai/presentation/sidebar/ai_ask_view.dart` | Scope picker, `MathText`, tier banner, notice state |
| `lib/features/ai/presentation/sidebar/ai_explain_view.dart` | `MathText`, tier banner |
| `lib/features/ai/presentation/knowledge_graph/knowledge_graph_screen.dart` | Scope menu; readable maths in node labels |
| `lib/features/summarize/presentation/{summarize_notifier,summarize_providers}.dart`, `widgets/summary_bottom_sheet.dart` | Tier plumbing, `MathText`, guard wiring |
| `lib/editor/import/scene_import_service.dart` | `newImportGroupId`, `importSourceNameOf` |
| `lib/editor/ui/notebook_editor_screen.dart` | Tags imported pages, eager-indexes them, "Index all pages", scoped summarize, `pageId` on the graph route |
| `lib/editor/ui/controls/editor_app_bar_actions.dart` | "Index all pages" menu item |
| `lib/app/router.dart` | Optional `pageId` query param on the graph route |
| `pubspec.yaml` | `flutter_math_fork: ^0.7.3` (added; no pinned package touched) |

### Added — tests (160 new)
`ai_scope_test.dart`, `rag/bulk_indexer_test.dart`, `tutor_voice_test.dart`,
`math_markup_test.dart`, `quality/output_quality_test.dart`,
`quality/ai_quality_guard_test.dart`, `chat_commands_test.dart`,
`grounding_audit_test.dart`, `presentation/cloud_model_toggle_test.dart`, plus
new scope cases in `rag/rag_retriever_test.dart`.

---

## 3. Workstream by workstream

### A — Tutor voice, not assistant voice
The register lived in three files in three slightly different forms, so the same
student heard a different voice depending on which button they pressed. It is now
one constant, `kTutorVoice`, used by `Explainer._base`, `NotesQa.systemPrompt`
and `SummarizationService._voice`.

The instructions **name each AI tell individually** rather than asking for
"natural writing" — a model reads the latter as a style adjective and keeps its
defaults. Named and forbidden: assistant framing ("As an AI", "I'd be happy to",
"Certainly", "Great question", the closing offer of help), the rote "Let's break
this down step by step" opener, rule-of-three padding, inflated framing ("it is
important to note that", "delve into", "plays a crucial role"), connective filler
("Furthermore", "Moreover", "In conclusion"), vague authority ("experts say",
"studies show"), headings/bullets/emoji, and more than one dash per reply. Asked
for positively: varied sentence length, direct address, specifics from the
student's own material, plain confident statements where the material supports
them, and a specific (never generic) check for understanding.

**Faithfulness was not traded for it.** In `NotesQa` the grounding rule is stated
*before* the style rules, deliberately — "state it plainly and confidently" read
before "use only the passages" is an invitation to fill a gap confidently. A test
asserts that ordering. The Context Engine takes the maths convention but *not*
the prose voice: it emits JSON, and there is no reader to sound natural for.

*Tests:* `tutor_voice_test.dart` (33) covering "every prose prompt carries
the voice", each named tell, each positive behaviour, and a `faithfulness
survives the rewrite` group pinning the exact `notFoundReply`, Explain's
"never invent specifics / contradict it", Summarize's "never invent facts", and
the Context Engine's "never invent".

### B — Grounding audit
Audited every `systemPrompt:` call site. Ask, Explain, Summarize and the Context
Engine all build prompts exclusively from retrieved passages or extracted page
content. Research is the one feature permitted to reach outside the notes, and
says so in its own header — it is excluded deliberately.

**One real hole found and closed.** `NotesQa.answer` guarded its empty-sources
precondition with an `assert`, which is debug-only. In a release build, a caller
bug would send a bare question under a system prompt saying "use only the
passages below" — and a model shown no passages answers from world knowledge,
while the UI presents the result as coming from the student's notes. The assert
is now a real guard that returns `notFoundReply` without reaching the model. It
is also, being real code, testable — which an assert is not.

*Tests:* `grounding_audit_test.dart` (10) — a recording provider captures exactly what
reached the model for each feature, plus prompt-contract assertions (including
that a page the meaningfulness gate rejects never reaches the model at all).

### C — Multi-page RAG and scope (the core bug)
**The bug:** `RagIndexScheduler` fires only from the Context Engine's per-page
"text changed" hook, which only ever runs for the page on screen. So an imported
PDF was invisible to retrieval except for whichever single page the user happened
to open — and nothing in the UI explained why.

**1. Eager + bulk indexing.** `BulkRagIndexer` takes a page-id list and indexes
each in turn. Two triggers: the tail of `_importPdf` (so a document is searchable
before the student flips through it) and an explicit **"Index all pages"** action
in the editor overflow menu, for notebooks that predate this. It reads with
vision on — an imported page is a picture, and the light ML Kit path reduces a
slide to stray labels. Design choices, each documented in the file: sequential
rather than concurrent (the on-device models are single-instance behind a mutex);
one page's failure never sinks the batch; a missing embedding model stops the run
rather than failing 40 pages identically; cancellable at page boundaries.

**2. Scope control.** `AiScopeKind { selection, page, importGroup, notebook }`,
resolved by `AiScopeResolver` and wired into:
- **Ask** — `RagRetriever.search` gained a `pageIds` filter and
  `NotesQa.findSources` a `scope`. Filtering happens *at retrieval*, not on the
  answer: the grounding contract is that a passage outside the scope never
  reaches the prompt at all. An **empty** page set returns nothing rather than
  widening to the notebook.
- **Summarize / Explain / Knowledge graph** — see D and E.

Defaults: Ask defaults to the whole PDF when the current page came from one, and
the whole notebook otherwise — asking your notes is normally a "somewhere in
here" question, so defaulting to one page would turn most useful questions into a
"not found". Explain and Summarize stay page-local. "Whole PDF" appears in the
menu under exactly one rule (this page has an import group), shared by all three
surfaces so they can never disagree.

*Tests:* `ai_scope_test.dart` (12), `bulk_indexer_test.dart` (9) and new
`rag_retriever_test.dart` cases (6). The regression test is explicit and
two-sided: a 3-page import is bulk-indexed with **no page ever opened**, and a
question whose answer lives on the *last* page retrieves it; the paired test
indexes only page 10 (as the old live scheduler would) and asserts page 12 stays
invisible.

### D — Summarize scope
`ImportGroupScope` added to the sealed `SummarizeScope`, and
`SummarizeScopeChoice` extended with `importGroup`. The editor resolves it
through the same `AiScopeResolver`. **"This page" still means exactly the one
open page** — it is hard-wired rather than going through the resolver, because
there is nothing to resolve and it must never pull a neighbour in.

An import-group summary is deliberately **not** cached: the notebook cache is one
entry per notebook, and sharing it would show a student their lecture-PDF summary
as the summary of their whole notebook.

### E — Knowledge graph scope
`knowledgeGraphProvider` is now keyed by `KnowledgeGraphRequest (notebookId,
kind, pageId)` instead of a bare notebook id, and the screen shows the same scope
menu (only when it was opened from a page — the route now carries `?pageId=`).

This needed page attribution on the *edges*: `ConceptMastery` already had
`lastPageId`, `ConceptRelation` did not, so `ConceptRelationRecord.lastPageId`
was added and `observePageContext` populates it. A scoped graph reads the **same
extraction path** as the notebook-wide one — the Context Engine's per-page
analysis — so narrowing is a filter over what it already recorded, not a second
pipeline. Concepts with no page attribution are excluded from a narrowed graph
rather than included: a graph that quietly widened its own scope would be worse
than one that admits it is sparse.

### F — Mathematical expressions
**1. Convention.** `kMathMarkup` instructs LaTeX in `$…$` / `$$…$$`, with worked
examples, an explicit ban on Unicode-symbol maths and on undelimited commands,
and "prose stays prose". It reaches every prose prompt *and* the Context Engine
(a definition the note gives may itself be a formula, and the graph and
flashcards are built from those).

**2. Renderer.** `flutter_math_fork: ^0.7.3` added (the actively-maintained fork;
the original was last published in 2021). Pure Dart, no native code, so it cannot
collide with the pinned ML Kit plugins — verified: `pub get` moved no existing
package and added one transitive dependency (`tuple`). **No pinned dependency was
touched.**

`parseMathSegments` is a pure reader for the convention, with a stated rule for
every ambiguity: *when in doubt it is prose*. Currency (`$30 and the notes cost
$5` — two dollar signs that pair up perfectly) stays prose; an unclosed delimiter
mid-stream stays prose and resolves when the closing `$` arrives; an escaped `\$`
is literal; an empty pair renders as written. Segments round-trip to the source
byte for byte, so nothing the model wrote can be lost by rendering.

`MathText` is wired into `ai_explain_view.dart`, `ai_ask_view.dart` (answer *and*
source snippets) and `summary_bottom_sheet.dart`. Prose renders as plain `Text`
exactly as before — the segmented path only engages when there is maths. A
formula that won't parse falls back to its LaTeX source rather than an error box.

**3. Round-trip verification.** `math_markup_test.dart` (24) carries a fixture answer
containing the quadratic formula (as a `$$` block) and a derivative
(`$f'(x) = 3x^2$`), and asserts the block is a block, the coefficients and
derivative are inline maths, **no LaTeX command escapes into a prose segment**,
and the whole answer round-trips.

**Two genuine bugs were found by these tests during development** and fixed: the
currency heuristic was swallowing half a sentence between two prices, and the
parser's `.trim()` broke the round-trip guarantee.

### G — Accuracy fail-safe → cloud fallback
`checkOutputQuality` (pure) detects: empty/near-empty, repetition loops (a
5-word window recurring 3×), degenerate text (type-token ratio below 0.25 on
25+ words), answers that share almost no vocabulary with their passages, and —
for grounded features — numbers the passages never state. Every threshold is a
named constant with its reasoning, because they are judgement calls, not
measurements.

`AiQualityGuard` runs local → checks → escalates, implemented **once** and used
by Ask, Explain, Summarize and the Context Engine.

**The privacy contract is the load-bearing part**, and it shapes the class:
- `localOnly` → never escalates. Low-confidence warning, no button.
- `allowCloudForNonSensitive` → escalates automatically, result marked
  `cloudVerified` and badged in the UI.
- `askEachTime` (**the default**) → **does not escalate on its own initiative.**
  The result comes back flagged low-confidence with `canRetryOnCloud`, and the UI
  offers a "Check with the cloud model" button. The cloud call happens because
  someone pressed something. Silently escalating here would have been the easy
  implementation and would have broken the invariant this codebase is most
  careful about.

Two further deliberate properties: a **grounded refusal is exempt** — a correct
"not in your notes" is short and shares no vocabulary with the passages, i.e.
exactly what the "ignored its sources" heuristic looks for, and escalating it
would have the cloud answer it from world knowledge, destroying the contract the
feature exists for. And a **cloud answer that is also broken is not marked
verified** — a network call does not make an answer correct.

Streaming is preserved: local output streams through `onPartial` while it is
checked, so the fail-safe costs nothing in perceived latency in the common case.
On escalation `onPartial` is called from empty again, so the UI *replaces* the
bad answer rather than appending to it.

The UI half is `AnswerTierBanner`, above the answer (a warning read after the
answer has been taken in has done half its job), in Ask, Explain and Summarize.
A low-confidence summary is also not cached — caching it would pin the bad recap
to the notebook until its text changed.

*Tests:* `output_quality_test.dart` (17) and `ai_quality_guard_test.dart` (17).
Both required cases are covered explicitly: a degenerate local response triggers
the cloud path with a fake cloud provider, **and** a good local response does not
(`cloud.calls == 0` — "no over-triggering"), plus the refusal-exemption case, all
four privacy paths, offline, no-provider, and cloud-also-broken.

**A real bug was found by these tests**: `[1]`/`[2]` citation markers — which
`NotesQa` *orders* the model to write — were being read as unsupported numeric
claims, which would have flagged every correctly-cited answer.

### H — Cloud toggle: button and chat command
**1. Header switch.** `CloudModelToggle` in `_SidebarHeader`, bound to
`settingsProvider.cloudAiEnabled` via `setCloudAiEnabled`. It changes the opt-in
default and **nothing else** — `cloudPrivacy` and `hasSeenFirstCloudCall` are
untouched, so the `askEachTime` per-call confirmation contract still applies. The
tooltip says so explicitly ("you're still asked before anything is sent"). A test
asserts the privacy fields are unchanged after a tap.

**2. Chat command.** `parseChatCommand` handles `/cloud on|off|enable|disable|
yes|no`, a bare `/cloud` (reports state rather than guessing), unknown slash
commands (recognised so `/clod on` isn't sent to the model as a question), and a
short fixed list of natural phrasings ("use the cloud model", "switch to local
model", "turn off cloud AI", "go local"). Commands are intercepted in
`AskNotesNotifier.ask` *before* retrieval and answered with an `AskNotesNotice`.

Natural phrasing is matched **narrowly and against the whole input**, by fixed
list rather than pattern. Anything cleverer starts eating questions about cloud
storage and cumulus clouds, and a question silently swallowed by a settings
change is far worse than a phrasing that wasn't recognised. Eight such questions
are in the test suite asserting they reach the model untouched.

*Tests:* `chat_commands_test.dart` (21) and `cloud_model_toggle_test.dart` (11),
including the sync test the workstream asked for: flipping the setting via the
command updates the header switch, and flipping the switch changes what a bare
`/cloud` reports — they read one stored value.

---

## 4. Invariants re-checked against the final diff

| Invariant | Status |
|---|---|
| Cloud never silent | Held, and strengthened. The guard's `askEachTime` path is the only new cloud trigger and it requires a tap. Four tests assert `cloud.calls == 0` under `localOnly`, `askEachTime`, cloud-off and offline. |
| `NotesQa.notFoundReply` exact string | Unchanged and asserted literally. Also now returned by the release-safe empty-sources guard. |
| Explain never invents contradicting facts | Prompt rule intact, asserted for all 7 modes. |
| Context Engine "never invent" | Intact and asserted. |
| Pinned dependencies | Untouched. `google_mlkit_digital_ink_recognition: 0.14.2`, `google_mlkit_text_recognition: ^0.15.1` and `flutter_gemma: 1.3.0` are byte-identical; only `flutter_math_fork` was added. |
| No existing feature regressed | Quiz, Flashcards, Research and Study Planner all untouched in behaviour; their tests pass unchanged. |

---

## 5. Known limitations and remaining work

1. **No device validation.** Everything is verified by the analyzer and 1381
   unit/widget tests. Nothing here has been run against a real Gemma model on a
   phone, so the *tone* improvement from Workstream A is asserted at the prompt
   level only — that is the honest limit of what a unit test can reach, and the
   manual QA below is how it actually gets checked.
2. **The cloud gateway is still not deployed.** `cloudGatewayBaseUrl` points at a
   Render URL that has not been stood up, so the escalation path in G is
   exercised by fake providers in tests and will fail over to
   "low confidence" in the app until the gateway is live. The failure is graceful
   and tested (`a cloud failure keeps the local answer rather than erroring out`).
3. **`kMinRelevance = 0.45` is still provisional.** Pre-existing, unchanged, and
   still un-measured against real EmbeddingGemma vectors on the target device.
   Scoping makes it matter slightly more: a narrow scope has fewer candidates, so
   a too-high floor produces "not found" sooner.
4. **Knowledge-graph labels don't typeset maths.** `flutter_math_fork` renders as
   a widget and the graph is a `CustomPainter`; rebuilding it out of positioned
   widgets would trade one cheap paint for hundreds of laid-out widgets on the
   screen most likely to be dense. Labels go through `mathAsPlainText` instead,
   so `$E = mc^2$` reads `E = mc²` rather than dollar-fenced backslashes.
5. **Selection is lost where `MathText` replaced `SelectableText`** in Explain and
   Ask — a rendered formula is a widget, not glyphs. The existing Copy button
   covers what selection was for.
6. **Concepts recorded before this change have no `lastPageId`**, so they appear
   only in the notebook-wide graph until their page is re-analysed. Excluding
   them from a narrowed scope is the deliberate choice (see E).
7. **The quality heuristics are heuristics.** Tuned to fire on obviously broken
   output rather than merely mediocre output; a false positive costs a cloud
   round-trip or a low-confidence badge on a decent answer. There is no check for
   whether an explanation is *good* — that needs a model, and is what the cloud
   tier is for.

No external blockers were hit: the Flutter toolchain, `build_runner` and
`flutter_math_fork` all resolved and ran.

---

## 6. Manual QA

### Setup
A notebook with (a) two or three hand-written pages, and (b) a multi-page PDF
imported into it — ideally one with a formula on a later page. The on-device LLM
and EmbeddingGemma both downloaded (Settings → AI).

### 6.1 Whole-PDF RAG — the core fix
1. Import a multi-page PDF (⋮ → import → PDF). Wait for "Imported N pages."
2. **Do not open any of the imported pages.** Stay on page 1.
3. Open the AI panel → **Ask notes**.
4. Confirm the scope chip under the query box reads **Whole PDF (yourfile.pdf)**.
5. Ask something whose answer is only on the *last* page of the PDF.
   - ✅ It answers, and the source cards cite that page.
   - ❌ Before this fix, this returned "not in your notes".
6. Tap the scope chip → **This page** and ask the same question.
   - ✅ Now it correctly says it can't find it — the scope is real, not cosmetic.
7. Switch to **Whole notebook** and ask about your hand-written pages.
   - ✅ Answers from those.

**Retroactive path:** open a notebook imported before this build, ⋮ → **Index all
pages**, wait for the "N pages added to search" toast, then repeat step 5.

### 6.2 Natural tutor voice
1. Select a paragraph of notes → **Explain** → *Beginner*.
2. Read the first two sentences and check for:
   - ❌ "Certainly!", "Great question", "As an AI", "I'd be happy to"
   - ❌ "Let's break this down step by step" as the opener
   - ❌ "It's important to note that", "delve into", "plays a crucial role"
   - ❌ "Furthermore", "Moreover", "In conclusion"
   - ❌ more than one dash in the whole reply
   - ❌ bullet points, bold headings, emoji
   - ❌ a closing "Let me know if you'd like more!"
   - ✅ varied sentence length, "you", an example taken from *your* note
   - ✅ sometimes a short specific question at the end (not "does that make
     sense?")
3. Repeat with **Ask notes** and with **Summarize → This page**. All three should
   sound like the same tutor.
4. **Faithfulness check:** ask your notes something they genuinely don't cover.
   - ✅ Exactly "I couldn't find the answer to that in your notes." with no
     source cards. The naturalness work must not have loosened this.

### 6.3 Maths rendering
1. Write (or import) a page containing a quadratic formula and a derivative.
2. Select it → **Explain** → *Mathematical*.
   - ✅ The quadratic renders as a typeset fraction with a radical, centred on its
     own line.
   - ❌ Raw `\frac{-b \pm \sqrt{b^2-4ac}}{2a}` as text is a failure.
3. **Ask notes** a question about it — the answer and the source snippets should
   both typeset.
4. **Summarize → This page** — same.
5. **Currency regression:** write "The textbook cost $30 and the notes cost $5"
   on a page and summarize it.
   - ✅ Both prices show as text; no part of the sentence vanishes into a formula.

### 6.4 Cloud fail-safe
Easiest to observe by making local output fail. With a small/quantised model,
asking a long multi-part question of a nearly-empty notebook will often produce a
loop or an empty reply.

1. **Settings → cloud privacy = Ask each time** (the default), cloud AI **on**.
2. Provoke a bad local answer.
   - ✅ A warning appears **above** the answer: "The on-device model got stuck
     repeating itself" / "…doesn't seem to be based on the passages it found",
     plus "Don't rely on it without checking your notes."
   - ✅ A **"Check with the cloud model"** button.
   - ✅ **Nothing has gone over the network yet** — verify with a proxy or by
     turning airplane mode on before provoking it (the button should then be
     absent, since an offer that can't work isn't shown).
3. Tap the button.
   - ✅ The answer clears and re-streams from the cloud.
   - ✅ It ends badged **"Checked with the cloud model"**.
4. Set privacy to **Allow cloud for non-sensitive** and provoke another failure.
   - ✅ It escalates automatically and shows the cloud badge, with no button step.
5. Set privacy to **Local only**.
   - ✅ Warning shown, **no** button, no network call, ever.
6. **No over-triggering:** ask a normal question with good notes.
   - ✅ No banner, no badge, no warning. A good answer should look untouched.

### 6.5 Cloud toggle — both entry points
1. Open the AI panel. Top-right, beside the close button: a cloud icon and a
   switch, off by default.
2. Hover/long-press → tooltip reads "Cloud AI off — everything runs on your
   device".
3. Tap it on. Icon changes to a filled cloud; tooltip becomes "Cloud AI on —
   you're still asked before anything is sent".
4. Open **Settings** → confirm the cloud AI toggle there is now on, and that the
   privacy mode is **still** "Ask each time" (the switch must not have widened
   it).
5. Back in the AI panel → **Ask notes**, type `/cloud off`, submit.
   - ✅ Reply: "Cloud AI is off. Everything runs on your device."
   - ✅ The header switch flips itself off.
6. Type `/cloud` alone.
   - ✅ "Cloud AI is off. Type /cloud on to allow the cloud model."
7. Type `use the cloud model`.
   - ✅ Turns it on; switch follows.
8. Type `/clod on`.
   - ✅ "I don't know the command…" — not sent to the model.
9. **The one that matters:** type `What did I write about cloud computing?`
   - ✅ It is asked as a question. If this returns a settings confirmation, the
     command parser is over-matching.

### 6.6 Summarize and graph scope
1. On a page belonging to the imported PDF: **Summarize** menu → it offers
   *This page*, ***Whole PDF (yourfile.pdf)***, *Whole notebook* (and *Selected
   items* when something is selected).
2. Pick **Whole PDF** → the recap should cover material from across the document,
   not just the open page.
3. On a hand-written page → the **Whole PDF** row is absent (not greyed out).
4. Open the **Knowledge graph** from the editor → the filter icon in the app bar
   offers the same three scopes → **Whole PDF** shows only that document's
   concepts.
