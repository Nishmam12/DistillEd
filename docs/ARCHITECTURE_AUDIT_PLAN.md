# Margo — Architecture audit and fix plan

Audit of branch `embeddinggemma-2` at `1f36593` (2026-10-24). Covers `lib/`
(337 Dart files), `test/` (239 files), `server/ai-gateway`, CI, and the
existing docs.

## Verdict

The architecture is professional-grade. **Do not restructure or rewrite.**
The fixes below are targeted: one data-loss bug, two dependency-direction
problems, and some bypassed DI.

Already in good shape (keep as is):

| Area | Evidence |
| --- | --- |
| Layering | `domain/` imports no Flutter widgets, Isar, `data/`, `editor/` or `features/`. Only `dart:ui` geometry types. |
| Model | Sealed `SceneElement` hierarchy. Isar enum order is pinned by a test. Versioned, gated, non-destructive migrator. |
| Persistence | Per-element rows. An ordered write queue in `SceneController` prevents writes landing out of order. Upserts read only the id columns. Drag updates stay in memory until pen-up. |
| DI | Riverpod everywhere, with overrides for docs path, device profile and library. `retry: null` is set on purpose for model loads. |
| Resilience | Boot splash, `StartupFailureApp` with retry, `ErrorWidget` boundary, on-device `ErrorLog`. |
| Secrets | HF token kept in the keystore. `dev_secrets.dart` is empty and debug-only. |
| Quality gates | `flutter analyze`: no issues. `flutter test`: 2678 pass, 3 skipped. CI runs analyze, test, the 16 KB alignment check, gateway pytest, a Docker build and `pip-audit`. `strict-casts` and `unawaited_futures` are on. |
| Heavy work | PDF import, export and checksums run on isolates. Isar queries are async. |

Deliberate choices that are fine and should stay:

- `features/home/domain/models` are Isar `@collection` classes. Using Isar
  entities as domain models is pragmatic, and a separate entity + DTO layer
  would double the code for no gain.
- `flutter_riverpod/legacy.dart` (`StateNotifier`, 28 files). Moving these
  imports was TECH_MIGRATION_PLAN 3.2's explicit first step. Port to
  `Notifier` only when you edit a file for another reason, never as a big bang.
- The 11 `catch (_) {}`. Each one is best-effort cleanup or a
  revert-then-rethrow (`history_controller.dart:41`).
- `SceneElementRecord.elementId` has no index. Upsert scans one page's id
  columns through the `pageId` index, which is cheap at page scale. Adding an
  index would be a schema change for no measured win.

---

## Phase 1 — Fix the data-loss bug (do first)

SECURITY_REVIEW item 1 is **still open in code**. A pasted element whose
`relativeImagePath` is `margo.isar` or `../…` gets that file unlinked when its
page is deleted, and the user loses every notebook.

### 1.1 Contain deletes — `lib/data/persistence/content_purge.dart`

Guard the single place every delete goes through, the `rm` helper in
`deleteContentFiles`. Refuse any `rel` that is empty, absolute (starts with
`/` or `\`, or has `:` at index 1), or contains a `..` segment. Require it to
start with `notes/`. This covers the image, sidecar and audio callers in one
place. It needs no new dependency (`path` is only transitive, and adding a
dependency is a STOP-and-ASK under ARCHITECTURE §8).

### 1.2 Reject bad paths at the trust boundary — `scene_element_codec.dart:170`

The clipboard is untrusted input. On decode, drop any image element whose
`relativeImagePath` fails the same check. Reuse one helper for both: a
`static bool isSafeRelativePath(String)` on `StoragePaths`.

### 1.3 Stop passing absolute paths through — `scene_image_cache.dart:101`

`resolvePath` returns absolute paths unchanged. Make it return `''` for them,
so the image fails to load instead of reading arbitrary files.

### Checks

- One test: `deleteContentFiles` with `margo.isar`, `../x` and `/abs` leaves
  those files on disk, while `notes/1/imports/a.png` is removed.
- One test: a clipboard decode containing a bad path yields no image element.
- Mark item 1 Fixed in `docs/SECURITY_REVIEW.md`.

**Effort:** S

---

## Phase 2 — Stop the UI reaching past DI

`IsarService.instance` is called directly from widgets and notifiers. That
breaks the DI convention in ARCHITECTURE §7, and those paths can't be faked in
tests.

| File | Fix |
| --- | --- |
| `editor/ui/notebook_editor_screen.dart:145, 866, 874, 883, 892` | Use `ref.read(noteRepositoryProvider)`. Add a `NoteRepository.get(id)` for line 145. |
| `editor/ui/notebook_book_view_screen.dart:59` | Same. |
| `features/home/presentation/home_notifier.dart:88` and `editor/state/page_notifier.dart:159` | Keep them as the only two places that touch the singleton. They are providers, which is where it belongs. |

Also in `notebook_editor_screen.dart`, `_setLayoutMode`, `_setTemplate`,
`_setPaperColor` and `_rename` mutate the local `Notebook` and then fire the
write without waiting. A failed write leaves the screen showing a value that
was never saved, and the home list never learns about the change. Make them
`async`, await the write, and call `homeNotifierProvider.notifier.loadNotebooks()`
afterwards (or invalidate it). Show a SnackBar on failure.

**Checks:** analyze clean. An existing editor widget test passes with a
fake `noteRepositoryProvider` override. **Effort:** S

---

## Phase 3 — Fix dependency direction

Import analysis found two cycles. Neither is breaking anything today, but they
are why the editor screen has 48 imports and why changing an AI provider
touches the canvas.

### 3.1 `editor` ⇄ `features`

`editor/` should be the reusable canvas engine (state, input, render, tools).
Today it also hosts the notebook *screen*, which wires in AI, audio, search,
summarize and home:

- `editor/ui/notebook_editor_screen.dart` imports 13 feature presentation
  files.
- `editor/ui/controls/selection_bar.dart` imports `ai_providers`,
  `recording_notifier`.
- `editor/ui/scene_canvas.dart` imports `audio_providers`.
- `editor/ui/controls/editor_app_bar_actions.dart` imports `home_notifier`.

At the same time, `features/ai/presentation` imports `editor/` 11 times.

**Fix:** move the screens, not the engine. Create
`lib/features/notebook/presentation/` and move `notebook_editor_screen.dart`,
`notebook_book_view_screen.dart`, `selection_bar.dart` and
`editor_app_bar_actions.dart` into it. For `scene_canvas.dart`'s audio hook,
pass a callback or `Widget?` slot in from the screen instead of reading
`audio_providers` inside the canvas. Afterwards, `grep -rn "features/" lib/editor`
should return nothing except `home/domain` models and the import/export
services.

Do it as a pure move: one commit, no logic changes, then `graphify update .`.

### 3.2 `features/ai/domain` → `features/ai/data`

- `ai/domain/page_content_extractor.dart:27-28` imports the concrete
  `HandwritingRecognitionService` and `GemmaVisionOcrService`. Have it take the
  abstractions it actually calls (`ImageTranscriber` already exists for the
  OCR side). If the handwriting service has no interface, move the extractor to
  `ai/data/` instead. Don't invent an interface for one implementation.
- `ai/domain/tools/web_search_tool.dart` and `wikipedia_tool.dart` are HTTP
  clients (`dio`). Move them to `ai/data/tools/`. `Tool` stays in domain.

**Checks:** analyze, full tests, re-run the import scan (Appendix). **Effort:** M

---

## Phase 4 — Opportunistic (only when touching the file)

Do not schedule these as their own work.

- **`ai_providers.dart` (785 lines, about 50 providers).** It is the AI
  composition root, and `ai_rag_providers.dart` already shows how to split it.
  When you next edit an area, move that area's providers out (OCR/vision,
  study, LLM runtime). `main.dart` and settings only need a few of them.
- **Large widgets.** `ai_context_view.dart` (796 lines), `notes_screen.dart`
  (758) and `ai_ask_view.dart` (679): extract private widgets into
  `widgets/` when you change them.
- **Schema list.** The 16 schemas in `main.dart` and `_logCollectionCounts`
  repeat each other. Keep one `const allSchemas` list in `isar_service.dart`
  and loop over it for the counts. Forgetting to register a new collection in
  one of the two places is the failure this prevents.
- **`StateNotifier` → `Notifier`.** Port per file as you touch it (see the
  Verdict).

---

## Pre-launch (already tracked in SECURITY_REVIEW)

- Gateway caller authentication: open, accepted pre-launch.
- Release signing: guarded by `-PrequireReleaseSigning=true`. Keep using that
  flag for every release build.

## Explicitly not recommended

- No move to "Clean Architecture" (repository interface + impl per store,
  use-case classes). One implementation per interface is ceremony.
- No swap of state management, router or database.
- No new dependencies.

## Appendix — import-direction scan

Re-run after phases 2 and 3 (it resolves relative imports, which `grep
package:margo` misses):

```bash
python3 - <<'EOF'
import os,re,collections
pat=re.compile(r"^\s*(?:import|export)\s+'([^']+)'",re.M); c=collections.Counter()
def layer(p):
    s=p.split('/'); return 'features/'+s[2]+'/'+s[3] if s[1]=='features' and len(s)>3 else s[1]
for d,_,fs in os.walk('lib'):
  for f in fs:
    if not f.endswith('.dart') or f.endswith('.g.dart'): continue
    p=os.path.join(d,f)
    for m in pat.findall(open(p).read()):
      if m.startswith('package:margo/'): t='lib/'+m[14:]
      elif m.startswith(('package:','dart:')): continue
      else: t=os.path.normpath(os.path.join(d,m))
      if layer(p)!=layer(t): c[(layer(p),layer(t))]+=1
for (a,b),n in sorted(c.items()): print(f'{a:32} -> {b:32} {n}')
EOF
```

Target edges to see disappear: `editor -> features/*/presentation`,
`features/ai/domain -> features/ai/data`.

## Progress log

- Phase 1 (2026-10-24, working tree): `StoragePaths.isSafeRelativePath`
  guards deletes, clipboard/library decode and `resolvePath`. It allows
  `notes/` **and `audio/`**, since recordings live under `audio/`. Tests:
  `test/data/persistence/content_path_safety_test.dart`. 2681 pass.
- Phase 2 (2026-10-24, working tree): the editor and book view read and write
  through `noteRepositoryProvider`. The four editor setters go through `_save`,
  which awaits the write, refreshes the home list (it was left stale after a
  rename or recolor) and reverts with a SnackBar on failure. No widget test
  covers it: no test pumps `NotebookEditorScreen` yet. Check on device: rename
  a note, go back, and the home list shows the new title.
