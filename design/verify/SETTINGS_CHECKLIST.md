# Settings screen — human verification checklist

Build the branch and open **Settings**. Everything below was verified statically
(`flutter analyze` only) — this machine cannot render the app, so these are the
claims a static check cannot prove.

Skips the obvious. Each line is something that could plausibly be wrong and that
you would not notice unless you looked for it.

**Setup:** you need to check both modes. Use the Theme row's own
System / Light / Dark control to switch — that also tests SET-09.

---

## The one the mockup gets wrong

The design mockup shows **gold row titles in dark mode**. The spec deliberately
overrides that. If dark-mode titles look gold, this pass failed its main point.

- [ ] **Dark:** "Trash", "Format", "Cloud AI", "Handwriting Language",
      "HuggingFace Token" titles are **cream/off-white**, NOT gold
- [ ] **Dark:** the section headers above them (APPEARANCE / NOTES /
      EXPORT DEFAULTS / AI) **are** gold — so title and header are visibly
      different colours in the same screenshot
- [ ] **Light:** titles and headers look like the *same* navy. They are the same
      hex on purpose — do not report this as a bug

## The chip asymmetry (highest risk — this widget ships to two more screens)

Selected chips are styled differently in each mode. This is intentional.

- [ ] **Light:** selected chip (PNG, English) is a **solid navy pill with white
      text**
- [ ] **Dark:** selected chip is **transparent with a gold outline and gold
      text** — NOT a filled gold pill
- [ ] **Both:** unselected chip (PDF, বাংলা) is transparent with a faint grey
      outline and grey text
- [ ] **Both:** the chip does not change size or jump when you switch theme
      (selected light and selected dark should occupy identical space)

## Segmented control (also ships to two more screens)

- [ ] **Light:** the track behind System/Light/Dark is **white**, slightly
      lighter than the page behind the card
- [ ] **Dark:** the track is a **dark grey that is visibly lighter than the card
      it sits in** — if you cannot see the track's edge at all, the light/dark
      track branch is wrong
- [ ] **Both:** the selected segment has a tinted fill with accent-coloured text
      AND icon; unselected segments have grey text and grey icons
- [ ] **Dark:** the selected segment's tint is actually visible against the track
      (it is only 16% gold — this is the pair most likely to be too subtle)
- [ ] Hairlines between the three segments are visible in both modes

## Cards and shadows

- [ ] **Light:** cards have a soft shadow and **no visible outline**
- [ ] **Dark:** cards have a **1px hairline outline and no shadow** — a dark card
      with neither is the failure mode; look at the card's edge against the page
- [ ] **Dark:** the shadow is genuinely gone, not just hard to see
- [ ] The AI card's three rows (Cloud AI / Handwriting Language / HuggingFace
      Token) are in **one card**, separated by hairlines that start under the
      title text — NOT running the full width under the icons

## Theme control behaviour

- [ ] Tapping System / Light / Dark re-themes the app **immediately**, with no
      restart and no flicker
- [ ] The subtitle under "Theme" updates to match ("Follow system" /
      "Always light" / "Always dark")
- [ ] Force-quit the app and reopen — the choice **survived the restart**
- [ ] Set it to **System**, then change the OS light/dark setting — the app
      follows
- [ ] The moon icon on the Theme row stays a moon in all three states
      (it labels the setting; it is not a state indicator)

## Toggles

- [ ] **Light:** Cloud AI on = navy track, white knob
- [ ] **Dark:** Cloud AI on = gold track, **dark** knob (not white)
- [ ] **Both:** Cloud AI off is clearly distinguishable from on — check the off
      state in dark specifically
- [ ] The Material switch draws its own thumb shadow that this pass could not
      remove. If it looks wrong in dark mode, flag it — it is a known gap, not
      an oversight

## Text legibility (the pairs the spec flags as marginal)

- [ ] **Dark:** row descriptions (grey on the card) are comfortably readable, not
      muddy
- [ ] **Both:** the grey placeholder/description text sitting on the **icon tile
      fill** and the **segmented-control track** is readable — the spec calls
      these out as the two most likely to fall under contrast minimums
- [ ] **Dark:** the disabled "Download" button on the AI Models card is visibly
      dimmer than an enabled one, but still legible

## Script rendering

- [ ] The **বাংলা** chip renders Bengali glyphs properly — not tofu boxes
      (□□□), not obviously-different fallback letterforms next to the English
      chip. The app bundles Poppins and Nunito, neither of which covers Bengali,
      so this is falling back to a system font. **Report what it looks like** —
      no font was added to fix it, deliberately

## Icons

Row icons were swapped from Material to Phosphor in this pass.

- [ ] Every row icon rendered — no empty squares or missing glyphs anywhere,
      including the **AI Models**, **Developer** and **About** sections further
      down
- [ ] The back arrow in the app bar still goes back, and looks like the other
      Phosphor glyphs (not a leftover Material arrow)
- [ ] Chevrons on Trash / HuggingFace / About are **grey**, not gold — a gold
      chevron on every row would be the wall-of-accent problem

## Not done in this pass — expect these to look wrong

These are out of scope for the settings pass and are listed so you do not report
them as regressions.

- [ ] The **HuggingFace token dialog**, the **delete-model confirmation**, and
      the **free-up-space confirmation** are still on the OLD coral palette.
      Expected — the spec defers dialogs to the straggler sweep after all four
      screen passes
- [ ] **Every other screen in the app** (home, note editor, trash, about) is
      still coral. Settings is the first screen migrated
- [ ] Destructive actions ("Remove", "Delete") are still coral red. The nine-token
      spec has no destructive/error colour — it needs one

---

## If something is wrong

Note which checkbox, which mode, and whether it is a colour or a layout problem.
Colour problems trace to `lib/core/theme/app_colors.dart`; the shared chip and
segmented control live in `lib/widgets/`.
