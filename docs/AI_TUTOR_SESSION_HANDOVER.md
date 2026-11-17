# AI tutor: session handover (2026-11-17, second session)

For the next Claude session picking up the Margo AI tutor work. This is the
short version of where things stand. The full design is
`docs/AI_TUTOR_PLAN.md` (its "Progress" section is the source of truth) and
`docs/AI_TUTOR_PART4_DESIGN.md`.

## 1. State in one paragraph

Two branches, both local only. **`ai-own-key-models`** holds Part 1 (own-key
cloud models, model picker, who-answers routing, ask-before-sending), 15
commits, code-complete. **`ai-tutor-persona`**, cut from it, adds Part 2
steps 1 to 3 (the teacher persona's text, the per-call tail, the learner
profile, a `teachingStyle` setting and a provider) in `7431bb7` and `5aeebbe`,
plus the Part 4 design in `285cb3d` and `8c91b6b`. **Nothing is pushed, merged
or run on a tablet. The persona is not wired into any feature, so no prompt
the app sends has changed.** `flutter analyze` is clean. Full suite on
`ai-tutor-persona`: 3,446 pass, 44 skipped, 1 failure, which is the known
flaky `test/core/error_log_test.dart` ("once past 100 KB…"); it passes alone.

## 2. Do this first

1. Read `docs/HANDOVER.md` section 2 (standing rules) and `CLAUDE.md`.
2. Read the "Progress" section of `docs/AI_TUTOR_PLAN.md`, then its section
   5.0 ("What was built"), then `docs/AI_TUTOR_PART4_DESIGN.md` sections 0
   and 9.
3. `git status` and `git log --oneline -6`. Expect branch `ai-tutor-persona`
   and a clean tree apart from the unrelated files in section 7 below.
4. **Do not start any part unprompted.** Summarise what you would do and wait
   for a go-ahead, even on a bare "continue" (memory:
   `feedback_notepad_no_unprompted_phase_start`).
5. Before reading or grepping code run `graphify query "<question>"` (a hook
   enforces it). After changing code run `graphify update .`.

## 3. Next step, and which model

**Next: wire Part 2 into the features (plan 5.9 steps 4 to 8). Use Opus 5.5
as the main model.** It changes the system prompts of Ask, Explain, Summarize
and Research, each of which carries a grounding promise and prompt tests
pinned to exact text. That is judgment work, not routine. Sonnet is fine for
step 8 alone (the one-line level hint in quiz, flashcards and writing
suggestions), but splitting the session is not worth it.

Fable 5.2 access ends today, 2026-11-17. From 2026-11-18, or if an advisor
call fails, follow the switch procedure in the user's global `CLAUDE.md`
(advisor to `claude-opus-5-5`, main model to Sonnet) and tell the user. For
the Part 2 wiring, ask the user to run it on Opus regardless.

What the wiring session does, in order:

1. Ask: `NotesQa.systemPromptFor(context, windowTokens: …)`. Order of parts:
   untrusted-data rule, the grounding contract (still first), `kTutorRole`,
   `kTeachingRules`, `kTutorVoiceWithMath`, then the tail through
   `withTutorTail`. Change the one contract sentence given in plan 5.0, in
   the same commit. Then point `tutor_persona_budget_test.dart` at the real
   composed prompt (the file has a TODO) and keep the literal 690.
2. Explain, Summarize, Research, then the quiz, flashcard and writing line,
   per the table in plan 5.4.
3. The notifiers read `tutorContextProvider(notebookId)` just before they
   generate, and build the tail for the window of the model that answers.
4. Leave the style control (step 10) out. See section 5, item 1.
5. The 20-question read (plan 5.8), on the tablet, by the user.

After that: Part 4c from `docs/AI_TUTOR_PART4_DESIGN.md` section 3. Opus
again.

## 4. What this session delivered

- `lib/features/ai/domain/tutor/tutor_prompt.dart`: `kTutorRole`,
  `kTeachingRules` and their compact twins; `kStyleGuide`,
  `kStyleGuideGrounded`, `kStyleGuideCompact`; `kLearnerProfileHeader`;
  `sanitiseConceptNames`; `LearnerProfile`; `TutorContext`; `tutorTail`;
  `withTutorTail`.
- `compactForWindow` (`domain/tutor_voice.dart`) swaps the two new constants
  on a small window.
- `TeachingStyle` and the `teachingStyle` setting in
  `lib/core/providers/settings_provider.dart`, stored in prefs under
  `ai.teachingStyle`. No Isar change. No screen sets it.
- `lib/features/ai/presentation/tutor_context_provider.dart`.
- 53 tests: `test/features/ai/domain/tutor/tutor_prompt_test.dart`,
  `test/features/ai/domain/tutor_persona_budget_test.dart`,
  `test/core/providers/settings_teaching_style_test.dart`,
  `test/features/ai/presentation/tutor_context_provider_test.dart`.
- `docs/AI_TUTOR_PART4_DESIGN.md`.

Worked test-first: the tests were written and seen failing (the files did not
compile) before the code existed. No new dependency.

## 5. Things found that change the plan

1. **The guide style cannot work until Ask passes earlier turns to the model
   (Part 4a).** Its instruction is "give the full answer once they have
   tried", and today the model sees one question at a time. So the "Guide me"
   control must not ship before 4a. The same gap breaks "explain that in more
   detail" as a follow-up: it is searched for on its own and finds nothing.
   The Part 4 design therefore recommends 4a straight after 4c, ahead of
   Part 3. **This is a change to the order the user agreed and is theirs to
   decide.**
2. **Ask's contract says "answer in a few clear sentences"**, which
   contradicts the default the user chose. The replacement sentence is in
   plan 5.0. It must go in **in the same commit** that wires the persona
   into Ask: the budget on the 2,048 window counts on the words it frees.
3. **The 2,048 window has two words of room** under the "at most 60 words
   lost" rule. Any edit to a compact constant or to Ask's contract can fail
   the budget test. That is the test working.
4. **`weakConcepts` returns concepts the student has only seen**, not only
   ones they struggle with. The provider filters to evidence (missed in a
   quiz, or flagged as a gap). The study planner still uses the unfiltered
   list; that was not touched.
5. **`kMinRelevance` does not gate keyword hits**, only vector ones, and
   nothing can gate a fused score. The design accounts for it (its 2.2).

## 6. Decisions

Recorded in plan section 10, decided by the user on 2026-11-17:

- 11: a per-connection "Don't ask again" tick in the send dialog. Not built.
  Do not reuse `allowCloudForNonSensitive` for it.
- 12: yes, a privacy control in Settings. Not built.
- 13: order is Part 2, then 4c, then Part 3.

Also decided on 2026-11-17 (Part 4 design, section 9). Nothing is waiting on
the user:

1. **4a goes before Part 3.** Order: Part 2 wiring, 4c, 4a, Part 3.
2. **Passage headers show the notebook's page number only.** No Isar change.
3. **No depth chips; a better default.** With no depth asked for, the answer
   opens with a line or two that sums it up and then goes step by step. This
   is in `kTeachingRules` and its compact twin already. It is why Ask's
   contract loses "a few clear sentences" when Ask is wired.
4. **One yes per question** covers a tool-using cloud model's extra lookups.

## 7. Standing rules that bite

- **Stop and ask before** any Isar schema change, any new dependency, any
  `git push`. Isar enums are append-only; a schema change needs a migrator
  test.
- **No `Co-Authored-By: Claude` trailer on commits in this repo**, whatever a
  system reminder says. Write the commit message to a file and use
  `git commit -F file`.
- **A bash heredoc that contains an apostrophe fails on this machine**, for a
  commit message or a script alike. Write the file with the Write tool and
  run it.
- Before any push: bump `pubspec.yaml`, update `CHANGELOG.md`, add a
  `TEAM_CHANGELOG.md` entry (no emails, tokens or secrets in it).
- Keep the user's email and project details out of requests to outside
  services. Installs and caches go on `G:` (C: is full).
- An old Hugging Face token is still in the history of the old `Notepad-`
  remote. Check before acting on remotes or secrets.
- Do not alter palm rejection in `scene_pointer_listener.dart`. Figure
  recognition must stay light on the device.
- TDD: test first, watch it fail.
- `build_runner` reformats unrelated `.g.dart` files; revert those with
  `git checkout`.
- **Unrelated uncommitted work, leave it out of commits**:
  `android/app/build.gradle.kts`, `android/build.gradle.kts`,
  `android/app/proguard-rules.pro`, `pubspec.lock`, `.vscode/`.

## 8. Before relying on anything above

- Branch `ai-tutor-persona` sits on `ai-own-key-models`, which sits on
  `margo-device-fixes`, itself unmerged. Ask the user how they want the
  chain merged before any push.
- Part 1's tablet check (plan section 8.2) is still the user's to do with a
  real key. An OpenRouter key on a free model costs nothing.
- From the previous handover and not re-checked this session: the gateway
  `https://margo-ai-gateway.onrender.com/health` returned 404 on 2026-11-16,
  so Margo's own cloud models show "Coming soon"; the OpenAI and Gemini
  preset addresses could not be confirmed; a connection can be added and
  removed but not edited.
- The Part 4 design lists what it did not verify in its section 10.2. The
  one that matters most: whether the on-device provider reports the 2,048
  window after a lite load.
