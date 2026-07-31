# DistillEd — Light/Dark Theme Spec & Staged Prompts

Save this file in your repo as `design/THEME_SPEC.md`. Every prompt below tells
Claude Code to read it, so it becomes the single source of truth instead of you
re-describing the design four times.

Also save the two mockups in the repo:

```
design/THEME_SPEC.md                    <- this file
design/mockups/settings_light_dark.png  <- image 1
design/mockups/home_light_dark.png      <- image 2
```

Do **not** add the current note-editor screenshots. Reasons in "Do I upload the
images?" below.

> **Where this spec departs from the mockups**
> The mockups show gold row titles in dark mode. This spec uses cream for
> repeated content text and reserves gold for brand, headings, and active
> states. See "Color hierarchy" for why. Everything else follows the mockups.

---

## Do I upload the images?

**Yes — mockups 1 and 2, as files in the repo, referenced by relative path.**

Claude Code can open image files from the workspace. Chat-pasted images are less
reliable across editor integrations, and a path in the prompt survives context
compaction, session restarts, and being re-run later. Layout details — the
gradient bleed on the note card thumbnail, the icon-tile corner radius, the
hairline above the bottom bar — are things a text description will lose.

**No — the two current note-editor screenshots.** Those show the *before* state.
Claude Code reads the actual source for that, which is more accurate than a
screenshot. Feeding it "before" images risks it treating them as a reference to
preserve. Describe the note editor as a target instead (Prompt D does this).

**Images are not sufficient on their own.** Models eyeball hex values badly —
they will look at your cream background and write `#FFF8F0` or `#FAF6F0`. Ship
the images *and* the token table below, and state explicitly: token table wins on
color and hierarchy, images win on layout and component structure.

---

## Design tokens

Confirmed: `#192841` (navy, light accent), `#DDAC5F` (gold, dark accent).
Everything else is **eyeballed from the mockups — review before running Prompt
A.** If you have the original design file, pull the real values from there.

### Light

| Token | Hex | Used for |
|---|---|---|
| `bgPrimary` | `#F4F2EE` | Scaffold background |
| `surface` | `#FFFFFF` | Cards, settings rows |
| `surfaceSubtle` | `#F0EDE7` | Icon tiles, search field fill, toolbar strip |
| `accent` | `#192841` | Brand, headings, active/selected states, filled buttons |
| `onAccent` | `#FFFFFF` | Glyph/text on a filled accent surface |
| `textPrimary` | `#192841` | Row titles, note titles, content text |
| `textSecondary` | `#6E6A64` | Descriptions, placeholders, meta text |
| `border` | `#E6E2DA` | Card outlines, chip outlines, hairlines |
| `accentMuted` | `accent @ 12%` | Active-tool halo, selected segment fill |

### Dark

| Token | Hex | Used for |
|---|---|---|
| `bgPrimary` | `#0D0D0F` | Scaffold background |
| `surface` | `#1A1A1C` | Cards, settings rows |
| `surfaceSubtle` | `#232326` | Icon tiles, search field fill, toolbar strip |
| `accent` | `#DDAC5F` | Brand, headings, active/selected states, filled buttons |
| `onAccent` | `#14140F` | Glyph/text on a filled accent surface |
| `textPrimary` | `#E6E2DB` | Row titles, note titles, content text |
| `textSecondary` | `#8E8A84` | Descriptions, placeholders, meta text |
| `border` | `#2A2A2D` | Card outlines, chip outlines, hairlines |
| `accentMuted` | `accent @ 16%` | Active-tool halo, selected segment fill |

---

## Color hierarchy

This is the part that determines whether the app reads correctly. Read it before
touching any screen.

### Three tiers, not two

| Tier | Light | Dark | What gets it |
|---|---|---|---|
| Accent | `#192841` | `#DDAC5F` | Brand wordmark, screen + section headings, active/selected states |
| Primary | `#192841` | `#E6E2DB` | Row titles, note titles, counts, content text, inactive tool glyphs |
| Secondary | `#6E6A64` | `#8E8A84` | Descriptions, placeholders, meta text |

**In light mode, tier 1 and tier 2 are the same hex — this is intentional.**
`#192841` is dark enough to read as plain text, so it can carry both jobs without
anything looking emphasized. Do not "fix" this by inventing a second navy.

**In dark mode they must differ.** Gold is saturated and warm, so every gold
element reads as *emphasized*. If row titles, section headers, and selected chips
are all gold, none of them signals anything. Cream `#E6E2DB` for repeated content
text restores the hierarchy while staying in the same warm family as the
light-mode cream, so the two themes still feel like one system.

Avoid pure `#FFFFFF` here — it glows on OLED and fights the palette's warmth.

### Gold stays / cream takes over

**Keep `accent`:** the DistillEd wordmark; screen titles ("Settings"); section
headers (APPEARANCE / NOTES / EXPORT DEFAULTS / AI); single-instance chrome
glyphs (back arrow, overflow, search leading icon, filter, settings row icon
tiles, meta-row icons); every selected or active state.

**Change to `textPrimary`:** settings row titles (Trash, Format, Cloud AI,
Handwriting Language, HuggingFace Token); home note card titles; the "1 Note"
count; the note editor's note title; **inactive** tool glyphs in the note editor.

The single-instance glyphs stay gold because one of each appears per screen — 
they don't compete. Row titles and note titles repeat, and thirty gold titles
in a note list is a wall of accent color.

### Contrast reference

| Pair | Ratio | Verdict |
|---|---|---|
| `#192841` on `#F4F2EE` | ~13:1 | AAA |
| `#DDAC5F` on `#0D0D0F` | ~9:1 | AAA |
| `#DDAC5F` on `#1A1A1C` | ~8:1 | AAA |
| `#E6E2DB` on `#0D0D0F` | ~14:1 | AAA |
| `#8E8A84` on `#1A1A1C` | ~5:1 | AA |
| `#6E6A64` on `#FFFFFF` | ~5.3:1 | AA |

The two worth re-checking after build: `textSecondary` on `surfaceSubtle` in
either mode, and the 40%-opacity disabled state in NOTE-05.

---

## Deliberate light/dark asymmetries

These are **not** symmetric inversions. Do not "normalise" them.

| Component | Light | Dark |
|---|---|---|
| Selected chip (PNG, English) | Filled `accent`, `onAccent` text, no border | Transparent fill, 1px `accent` border, `accent` text |
| Unselected chip (PDF, বাংলা) | Transparent, `border` outline, `textSecondary` | Transparent, `border` outline, `textSecondary` |
| Segmented control — selected | `accentMuted` fill, `accent` text + icon | `accentMuted` fill, `accent` text + icon |
| Segmented control — track | `surface` | `surfaceSubtle` |
| Toggle (Cloud AI), on | `accent` track, white thumb | `accent` track, dark thumb |
| Compose FAB (home) | Filled `accent`, `onAccent` glyph | Filled `accent`, `onAccent` glyph |
| Card action button (spark) | `surface` circle, `accent` glyph, soft shadow | `surface` circle, `accent` glyph, 1px `accent` ring, no shadow |
| Search field | `surfaceSubtle` fill, no outline | `surfaceSubtle` fill, 1px `border` outline |
| Inactive tool glyph | `textPrimary` (= navy, same as active) | `textPrimary` (cream, differs from active gold) |

Shadows generally: present and soft in light, replaced by hairline borders in
dark. Do not carry `BoxShadow` into dark mode.

**On that last row:** in light mode, inactive and active tool glyphs are both
navy, so the `accentMuted` halo alone carries the active state — which works
fine against white. In dark, the active glyph also shifts from cream to gold.
The asymmetry is inherent to the palette, not a mistake. Do not unify it.

---

## Open decision — note paper in dark mode

Both current note-editor screenshots show cream paper. **Default for Prompt D:
keep the paper cream (`#FBF7EA`) in both modes**; only the chrome around it
themes.

Be aware of the tradeoff. The page is the largest surface on screen, and
`#FBF7EA` against a `#0D0D0F` backdrop is the biggest luminance jump in the app —
it somewhat defeats the purpose of dark mode for night use. The reason to accept
it: inverting the paper means inverting the handwriting strokes, which is a
rendering change to your ink pipeline, not a theming change, and it is out of
scope for this stage.

If you want to revisit it later, the cleaner path is a separate "night reading"
toggle that inverts paper *and* ink together, rather than tying it to `ThemeMode`.

---

## Why four prompts, not one

A single prompt covering theme infrastructure plus three screens produces a diff
in the hundreds of lines across a dozen files. If the token layer has a mistake,
every screen inherits it and you are reviewing three broken screens instead of
one wrong file. Run these in order, and verify each on a device before moving on.

Prompt A is the one that matters. B, C, and D are mechanical once A is right.

---

## Shared working method

All four prompts embed this. It is reproduced once here so you can tune it in
one place.

**Why visual work needs a different loop than the icon swap.** `flutter analyze`
proves the code compiles. It proves nothing about whether the screen looks right,
and nothing at all about dark mode — a screen can compile perfectly while being
entirely light-themed. So the loop adds two gates the icon prompt did not need: a
**color-source audit** (every color traced back to a token) and a **both-modes
declaration** (each spec item states its resolved value in light *and* dark).
Together these catch the two failure modes that actually happen: stray hardcoded
colors, and an agent that themes light mode and forgets dark.

```
## Working method — read this before anything else
Build SPEC BY SPEC in a VERIFY LOOP. Do not implement the whole screen
and check at the end.

Each item below is a numbered spec item. Rules:
- Work one SECTION at a time (a card, the app bar, the bottom bar).
  Within a section, apply every spec item that belongs to it, then
  close the loop before opening the next section.
- Loop per section: implement -> `flutter analyze` -> re-read the
  changed lines -> compare against the spec -> fix -> re-run. Repeat
  until clean. Only then move to the next section.
- Never mark a spec item complete from memory. Mark it complete only
  after re-reading the actual code and quoting it.
- DEFINITION OF DONE for a spec item. All three, or it is not done:
  (a) quote the current line of code,
  (b) name the token it reads from,
  (c) state the value that token resolves to in LIGHT and in DARK.
  If you cannot state both values, the item is not done.
- If a spec item cannot be completed, mark it BLOCKED, state why, and
  keep going with the others. Do not silently skip and do not
  improvise a substitute value.
- Maintain a running status table across the whole task, reprinted at
  the end of every section loop. Columns:
  spec id | element | token | light value | dark value | status
- After all sections are done, run the FINAL AUDIT pass. Do not report
  completion before that pass runs.
```

---

## PROMPT A — Theme foundation

```
# Task: DistillEd theme foundation (light + dark)

## Context
Flutter note app. Stage 2 of a UI overhaul (stage 1 was the Phosphor icon
swap, already done). This prompt builds ONLY the theming infrastructure.
No screen redesign in this pass.

## Source of truth
Read `design/THEME_SPEC.md` for the full token table, the color hierarchy
rules, and the component asymmetry table. Use those hex values EXACTLY.
Do not sample colors from the mockup images and do not invent values.

## Working method — read this before anything else
Build SPEC BY SPEC in a VERIFY LOOP. Do not implement everything and
check at the end.

Each item below is a numbered spec item (THEME-01 .. THEME-13). Rules:
- Work one FILE at a time. Within a file, apply every spec item that
  belongs to it, then close the loop before opening the next file.
- Loop per file: implement -> `flutter analyze` -> re-read the changed
  lines -> compare against the spec -> fix -> re-run. Repeat until
  clean. Only then move on.
- Never mark a spec item complete from memory. Mark it complete only
  after re-reading the actual code and quoting it.
- DEFINITION OF DONE for a token item: quote the line, and state the
  literal hex it resolves to in LIGHT and in DARK. Both, or not done.
- If a spec item cannot be completed, mark it BLOCKED, state why, and
  keep going. Do not silently skip.
- Maintain a running status table, reprinted at the end of every file
  loop: spec id | item | file | light value | dark value | status
- After all files are done, run the FINAL AUDIT (Step 3).

## Step 0 — Discovery (report before writing code)
1. How is theming currently handled? Report every `ThemeData`,
   `ColorScheme`, hardcoded `Color(0x...)`, and `Colors.*` usage, with
   file paths and line numbers.
2. Is there an existing theme-mode controller or persistence
   (shared_preferences, hydrated_bloc, etc.)? Report what state
   management the app already uses — match it, do not introduce a new
   one.
3. Count hardcoded colors in the codebase and give me the number. This
   is the baseline for stages B, C, and D.
4. Produce the initial status table with all 13 spec items marked
   PENDING and mapped to their target file.
Then WAIT for my confirmation before editing.

## Spec items

### File: lib/theme/app_colors.dart
- THEME-01  `ThemeExtension<AppColors>` exposing exactly these 9 fields:
            bgPrimary, surface, surfaceSubtle, accent, onAccent,
            textPrimary, textSecondary, border, accentMuted.
- THEME-02  `AppColors.light` — all 9 values from the spec's Light table.
            NOTE: `accent` and `textPrimary` are BOTH `#192841` in light.
            This is intentional per the spec's color hierarchy section.
            Do not deduplicate them into one field and do not alter one
            to make them differ.
- THEME-03  `AppColors.dark` — all 9 values from the spec's Dark table.
            NOTE: `accent` (#DDAC5F) and `textPrimary` (#E6E2DB) are
            DIFFERENT in dark. This is the core of the hierarchy. Do not
            set textPrimary to the gold.
- THEME-04  `copyWith` covering all 9 fields. Missing a field here is a
            silent bug; enumerate them explicitly.
- THEME-05  `lerp` covering all 9 fields, so theme transitions animate
            rather than snapping.
- THEME-06  `BuildContext` extension so screens read `context.colors.accent`
            instead of `Theme.of(context).extension<AppColors>()!.accent`.

### File: lib/theme/app_theme.dart
- THEME-07  `AppTheme.light` — `ThemeData` with `AppColors.light` registered
            in `extensions`.
- THEME-08  `AppTheme.dark`  — `ThemeData` with `AppColors.dark` registered
            in `extensions`, and `brightness: Brightness.dark`.
- THEME-09  Base theme derived from the SAME tokens so unmigrated widgets
            degrade gracefully instead of staying light: `colorScheme`,
            `scaffoldBackgroundColor`, `cardTheme`, `dividerColor`,
            `iconTheme`, `textTheme`, `appBarTheme`.
            Body text in `textTheme` maps to `textPrimary`, NOT `accent`.
            Set `useMaterial3: true` unless the app already opts out — if
            it does, tell me before changing it.

### File: theme mode controller (path per existing conventions)
- THEME-10  Controller exposing `ThemeMode` (system / light / dark) with a
            setter, using the app's EXISTING state management.
- THEME-11  Persisted to disk, restored on launch, defaulting to
            `ThemeMode.system` on first run.
- THEME-12  `themeMode` wired into `MaterialApp`, with `theme` and
            `darkTheme` both supplied.

### Deliverable (not code)
- THEME-13  Full inventory of remaining hardcoded colors: file, line,
            value, and which screen it belongs to. This drives B/C/D.

## Constraints
- Do NOT restyle any screen in this pass.
- Do NOT replace existing hardcoded colors yet — inventory them only.
- Do NOT assign theme colors to top-level constants, static finals, or
  anything captured outside `build()`. Theme switching must be live at
  runtime with no restart.
- Do NOT add new packages beyond a persistence package if none exists.
  If you need one, ask first.

## Step 3 — Final audit pass (mandatory)
Do not skip this even if every file loop passed.
1. Re-read every created file from disk, not from your memory of the
   edits.
2. Walk THEME-01..THEME-13 in order. For each, quote the code and state
   the light and dark values.
3. Confirm `copyWith` and `lerp` each handle all 9 fields. Count them.
4. Confirm every hex in `app_colors.dart` matches THEME_SPEC.md
   character for character. List any mismatch.
5. HIERARCHY CHECK: confirm light `accent` == light `textPrimary`, and
   dark `accent` != dark `textPrimary`. Both conditions must hold.
6. Run `flutter analyze`.
7. Confirm the app still builds and looks EXACTLY as it did before —
   nothing should visually change in this pass.
If the audit finds a discrepancy, fix it and re-run the audit from
step 1. Do not report completion on a partially passing audit.

## Step 4 — Report
Final status table, the controller's public API, and the hardcoded-color
inventory from THEME-13. Then STOP.
```

---

## PROMPT B — Settings screen

```
# Task: Restyle the settings screen to the new theme

## References
- Target mockup: `design/mockups/settings_light_dark.png`
  Left half = light mode, right half = dark mode.
- Tokens, hierarchy, and asymmetries: `design/THEME_SPEC.md`

Precedence: THEME_SPEC.md wins on all colors, opacities, hierarchy, and
the asymmetry table. The image wins on layout, spacing, corner radii, and
component structure. If they appear to conflict, ask me.

IMPORTANT: the mockup shows GOLD row titles in dark mode. The spec
overrides this — row titles use `textPrimary` (cream). Follow the spec,
not the image, on this specific point. See "Color hierarchy".

## Prerequisite
`lib/theme/app_colors.dart` and `lib/theme/app_theme.dart` exist from the
previous pass. Read them first. Every color in this screen must come from
`context.colors.*`. Zero hardcoded colors in the final diff.

## Working method — read this before anything else
Build SPEC BY SPEC in a VERIFY LOOP. Do not implement the whole screen
and check at the end.

Each item below is a numbered spec item (SET-01 .. SET-16). Rules:
- Work one SECTION at a time, in spec order. Close the loop on a section
  before opening the next.
- Loop per section: implement -> `flutter analyze` -> re-read the changed
  lines -> compare against the spec -> fix -> re-run. Repeat until clean.
- DEFINITION OF DONE for a spec item. All three, or it is not done:
  (a) quote the current line of code,
  (b) name the token it reads from,
  (c) state the value that token resolves to in LIGHT and in DARK.
  If you cannot state both values, the item is not done.
- Never mark an item complete from memory — re-read the code.
- BLOCKED is an acceptable status. Improvising a value is not.
- Running status table, reprinted after every section loop:
  spec id | element | token | light value | dark value | status
- After all sections, run the FINAL AUDIT.

## Spec items

### Chrome
- SET-01  App bar: back arrow + "Settings" title, both `accent`, zero
          elevation, background `bgPrimary`. Screen titles stay accent —
          there is one per screen, so it does not compete.
- SET-02  Section headers (APPEARANCE / NOTES / EXPORT DEFAULTS / AI):
          uppercase, letterspaced, small, `accent`.
- SET-03  Card container: `surface` fill, ~16px radius. Soft shadow in
          light; replaced by a 1px `border` in dark. Do not carry the
          shadow into dark.
- SET-04  Icon tile: rounded square ~12px radius, `surfaceSubtle` fill,
          `accent` Phosphor glyph.
- SET-05  Row typography: title `textPrimary`, description
          `textSecondary`.
          In DARK this means a CREAM title (#E6E2DB) over a GREY
          description — NOT gold. The mockup shows gold here; the spec
          overrides it. Gold in this screen is reserved for SET-01,
          SET-02, SET-04, and selected states.

### Shared widgets (build these first, B/C/D all consume them)
- SET-06  Segmented control widget, 3-way, full width. Track `surface`
          in light / `surfaceSubtle` in dark. Selected segment:
          `accentMuted` fill with `accent` text and icon. Unselected:
          transparent fill, `textSecondary` text and icon.
- SET-07  Chip pair widget. Selected: filled `accent` + `onAccent` text
          in LIGHT, but transparent + 1px `accent` border + `accent`
          text in DARK. This asymmetry is intentional — implement both
          branches, do not unify them.
          Unselected in both modes: transparent, `border` outline,
          `textSecondary` text.
Place both in `lib/widgets/`.

### Rows
- SET-08  Theme row: moon icon, subtitle reflecting current mode
          ("Always light" / "Always dark" / "Follow system"), with the
          SET-06 segmented control beneath it: System (gear) / Light
          (sun) / Dark (moon).
- SET-09  Theme control wired to the controller from Prompt A. Selecting
          a mode changes the app live and persists across restart.
- SET-10  Trash row: "Restore deleted notes for 30 days", trailing
          chevron, existing navigation preserved.
- SET-11  Format row: "Default format when exporting notebooks", with a
          SET-07 chip pair for PNG / PDF.
- SET-12  Cloud AI row: two-line description, trailing toggle. Toggle on
          = `accent` track.
- SET-13  Handwriting Language row: SET-07 chip pair, English / বাংলা.
          Verify the Bengali glyphs render — flag it if the font falls
          back.
- SET-14  HuggingFace Token row: trailing "Change" text button in
          `accent` plus a chevron.
- SET-15  SET-12, SET-13 and SET-14 share ONE card, separated by hairline
          `border` dividers inset to the text column (not full-bleed —
          see mockup).
- SET-16  Every shadow present in light is absent in dark, replaced by a
          border. Audit the whole screen for this, not just cards.

## Constraints
- Do NOT change behaviour, navigation, persistence, or handler logic.
  Visual layer only. SET-09 is the sole exception — the theme control is
  newly wired.
- Do NOT alter the Phosphor icons or sizes chosen in stage 1.
- Do NOT hardcode any color. `context.colors.*` only.
- Do NOT unify the SET-07 asymmetry.
- Do NOT use `accent` for row titles, however the mockup looks.

## Final audit pass (mandatory)
1. Re-read every modified file from disk.
2. Walk SET-01..SET-16. For each, quote the code, name the token, state
   light and dark values.
3. COLOR-SOURCE AUDIT: grep the modified files for `Color(0x`, `Colors.`,
   and any bare hex literal. Expected result: zero hits. Report every hit
   with file and line; each is a defect, not a note.
4. HIERARCHY AUDIT: list every widget on this screen that resolves to
   `accent`. The list should contain ONLY: app bar arrow and title,
   the four section headers, the six icon tiles, the selected segment,
   the selected chips, the toggle-on track, and the "Change" button.
   Any row title in that list is a defect.
5. BOTH-MODES AUDIT: confirm no spec item resolves to the same treatment
   in both modes where the asymmetry table says it should differ. List
   SET-07's two branches explicitly.
6. Run `flutter analyze`.
7. Confirm the screen renders in both `ThemeMode.light` and
   `ThemeMode.dark`, and that switching mode updates it live.
If the audit finds a discrepancy, fix and re-run the audit from step 1.

## Report
Final status table, list of shared widgets created, and the diff summary.
Then STOP.
```

---

## PROMPT C — Home screen

```
# Task: Restyle the home screen to the new theme

## References
- Target mockup: `design/mockups/home_light_dark.png`
  Top half = light mode, bottom half = dark mode.
- Tokens, hierarchy, and asymmetries: `design/THEME_SPEC.md`
- Precedence: spec wins on color and hierarchy, image wins on layout.

IMPORTANT: the mockup shows a GOLD note title and a GOLD "1 Note" count
in dark mode. The spec overrides both — they use `textPrimary` (cream).
The wordmark stays gold. See "Color hierarchy".

## Prerequisite
Read `lib/theme/app_colors.dart` and the shared widgets created in the
settings pass. Reuse them rather than rebuilding. Zero hardcoded colors
in the final diff.

## Working method — read this before anything else
Build SPEC BY SPEC in a VERIFY LOOP. Sections here are: header, search,
note card, bottom bar, states.

Each item below is a numbered spec item (HOME-01 .. HOME-17). Rules:
- One section at a time; close the loop before opening the next.
- Loop per section: implement -> `flutter analyze` -> re-read the changed
  lines -> compare against spec -> fix -> re-run.
- DEFINITION OF DONE: (a) quote the line, (b) name the token, (c) state
  the light AND dark resolved values. All three, or not done.
- Never mark complete from memory. BLOCKED is fine; improvising is not.
- Running status table after every section loop:
  spec id | element | token | light value | dark value | status
- After all sections, run the FINAL AUDIT.

## Spec items

### Header
- HOME-01  Scaffold background `bgPrimary`.
- HOME-02  "DistillEd" wordmark, heavy weight, `accent`. This is brand,
           so it stays gold in dark.
- HOME-03  Overflow "..." button, `accent`.

### Search
- HOME-04  Full-width pill (fully rounded), `surfaceSubtle` fill, `accent`
           leading magnifying-glass, `textSecondary` placeholder.
           NO outline in light; 1px `border` outline in dark.

### Note card
- HOME-05  Card container ~20px radius, `surface` fill. Shadow in light,
           hairline `border` in dark.
- HOME-06  Thumbnail bleeds to the right and bottom edges, with a
           horizontal gradient fading into the card surface on the left
           so the title stays legible. The gradient stops MUST be built
           from `context.colors.surface` so they track the theme. No
           hardcoded gradient colors.
- HOME-07  In dark mode the thumbnail is darkened via a scrim overlay.
           Do NOT ship a second image asset for this.
- HOME-08  Card title `textPrimary`, heavy weight. CREAM in dark, not
           gold — a list of thirty gold titles is a wall of accent color.
- HOME-09  Two meta rows: calendar icon + date, page icon + page count.
           Icons `accent`, text `textSecondary`.
- HOME-10  Circular action button on the card's right: `surface` fill,
           `accent` glyph. Soft shadow in LIGHT; no shadow but a 1px
           `accent` ring in DARK. Asymmetry is intentional.
- HOME-17  Text-over-image contrast: the gradient from HOME-06 must reach
           FULL opacity (100% `surface`) before the leftmost text column
           begins — the title and both meta rows must sit on flat surface
           color, never on the image itself. A bright patch in a
           thumbnail otherwise destroys the contrast guarantee. Verify
           with a light-colored thumbnail, not just the dune image.

### Bottom bar
- HOME-11  1px `border` hairline along the top edge, `bgPrimary` fill.
- HOME-12  Filter/sliders icon, left, `accent`.
- HOME-13  Note count label, centered, `textPrimary`. Cream in dark.
- HOME-14  Compose button, right: rounded square ~14px, filled `accent`
           with `onAccent` glyph. Note that in dark this is a gold fill
           with a DARK glyph — check the contrast direction.

### States
- HOME-15  Empty state (0 notes) renders correctly and themed. The mockup
           does not show this — derive it from the tokens and tell me
           what you built.
- HOME-16  List of many notes renders correctly, and a long note title
           truncates rather than overflowing or pushing the thumbnail.

## Constraints
- Do NOT change note loading, search logic, sorting, or navigation.
- Do NOT change the card's data model or which fields it displays.
- Do NOT hardcode any color, including gradient stops and scrim values.
- Do NOT use `accent` for note titles or the count label.
- Reuse the settings-pass shared widgets where applicable.

## Final audit pass (mandatory)
1. Re-read every modified file from disk.
2. Walk HOME-01..HOME-17, quoting code and stating both mode values.
3. COLOR-SOURCE AUDIT: grep for `Color(0x`, `Colors.`, bare hex. Zero
   hits expected. Every hit is a defect — report file and line.
4. HIERARCHY AUDIT: list every widget resolving to `accent`. Expected
   ONLY: wordmark, overflow button, search leading icon, the two meta
   icons, the card action glyph and its dark ring, the filter icon, and
   the compose button fill. A note title or count in that list is a
   defect.
5. BOTH-MODES AUDIT: confirm HOME-04, HOME-05, HOME-07 and HOME-10
   actually differ between modes as specified.
6. Run `flutter analyze`.
7. Confirm rendering with 0 notes, 1 note, and many notes, in both modes.
If the audit finds a discrepancy, fix and re-run from step 1.

## Report
Final status table, what you chose for the empty state (HOME-15), and the
diff summary. Then STOP.
```

---

## PROMPT D — Note editor

```
# Task: Restyle the in-note editor to the new theme

## Context
No mockup exists for this screen. Derive it from `design/THEME_SPEC.md`
so it sits in the same system as the settings and home screens. The
current editor uses a pink-tinted toolbar in light mode and a pure black
one in dark — both are being replaced.

## Prerequisite
Read `lib/theme/app_colors.dart` and the shared widgets from the previous
passes. Zero hardcoded colors in the final diff, with ONE documented
exemption (NOTE-10).

## Working method — read this before anything else
Build SPEC BY SPEC in a VERIFY LOOP. Sections here are: app bar, tool
strip, canvas, floating chips, footer.

Each item below is a numbered spec item (NOTE-01 .. NOTE-11). Rules:
- One section at a time; close the loop before opening the next.
- Loop per section: implement -> `flutter analyze` -> re-read the changed
  lines -> compare against spec -> fix -> re-run.
- DEFINITION OF DONE: (a) quote the line, (b) name the token, (c) state
  the light AND dark resolved values. All three, or not done.
- Never mark complete from memory. BLOCKED is fine; improvising is not.
- Running status table after every section loop:
  spec id | element | token | light value | dark value | status
- After all sections, run the FINAL AUDIT.

## Spec items

### App bar
- NOTE-01  `bgPrimary` fill, zero elevation. Trailing action glyphs and
           the back arrow in `accent`. The NOTE TITLE itself in
           `textPrimary` — it is user content, not a screen heading.

### Tool strip
- NOTE-02  `surfaceSubtle` fill with a 1px `border` hairline on its
           bottom edge. Replaces the current pink (light) and pure black
           (dark) treatments.
- NOTE-03  INACTIVE tool glyphs: `textPrimary`.
           In light this is navy; in dark this is cream.
- NOTE-04  ACTIVE tool: `accent` glyph on a circular `accentMuted` halo.
           In LIGHT the glyph color is unchanged from inactive (both
           navy) and the halo alone carries the state. In DARK the glyph
           ALSO shifts cream -> gold. This asymmetry is intentional and
           is what makes the active tool findable among twelve icons in
           dark mode. Do not unify the two branches.
- NOTE-05  Disabled undo/redo: `textSecondary` at 40% opacity. Confirm
           enabled/disabled are visually distinguishable in BOTH modes —
           this is the pair most likely to fail in dark.

### Canvas
- NOTE-06  Canvas backdrop `bgPrimary`.
- NOTE-07  Dot grid in `border`.

### Floating chips
- NOTE-08  Zoom percentage chip and color swatch chip: `surface` fill,
           soft shadow in LIGHT, 1px `border` in DARK. Same treatment as
           the home screen's card action button (HOME-10). Chip label
           text in `textPrimary`.

### Footer
- NOTE-09  Page footer bar: `surfaceSubtle` fill, `accent` glyphs,
           `textPrimary` for the "Page 1 / 1" label.

### The paper stays cream
- NOTE-10  Note paper remains `#FBF7EA` in BOTH modes. This is the one
           intentional hardcoded color in the app — it is paper stock,
           not a theme surface. Define it as a single named constant with
           a comment explaining the exemption, and reference that
           constant rather than repeating the literal.
           Do NOT invert, dim, or scrim the paper or the ink.

### Live switching
- NOTE-11  Switching theme while a note is open updates the chrome live,
           with no restart, no lost strokes, and no re-render of the
           canvas content.

## Constraints
- Do NOT touch drawing, stroke rendering, gesture handling, tool
  selection logic, page management, or persistence.
- Do NOT change the Phosphor icons or their sizes from stage 1.
- Do NOT change toolbar layout, ordering, or spacing.
- Do NOT make inactive tool glyphs `accent` — that is what broke the
  active state in the first draft of this spec.
- Visual layer only.

## Final audit pass (mandatory)
1. Re-read every modified file from disk.
2. Walk NOTE-01..NOTE-11, quoting code and stating both mode values.
3. COLOR-SOURCE AUDIT: grep for `Color(0x`, `Colors.`, bare hex.
   Expected: exactly ONE hit, the NOTE-10 paper constant. Any other hit
   is a defect — report file and line.
4. ACTIVE-STATE AUDIT: confirm that in DARK, the active tool glyph and
   the inactive tool glyphs resolve to DIFFERENT colors. If they are the
   same, NOTE-04 is not done.
5. Confirm NOTE-05 disabled state is legible in dark mode specifically.
6. Run `flutter analyze`.
7. Manually confirm NOTE-11: open a note, draw a stroke, switch theme,
   verify the stroke survives and the chrome updates.
If the audit finds a discrepancy, fix and re-run from step 1.

## Report
Final status table, and confirmation that the paper exemption is the only
hardcoded color remaining. Then STOP.
```

---

## After all four

Sweep for stragglers — dialogs, snackbars, bottom sheets, the trash
screen, and any onboarding flow will still be light-themed. Feed Claude Code
the THEME-13 inventory from Prompt A and work through what's left, using the
same spec-by-spec loop.

Then verify contrast on a real device in a dark room. The pairs most likely to
fall below 4.5:1 are `textSecondary` on `surfaceSubtle` in either mode, and the
40%-opacity disabled state from NOTE-05 in dark.
