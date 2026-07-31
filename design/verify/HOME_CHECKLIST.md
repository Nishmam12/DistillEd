# Home screen — human verification checklist

Build the branch and open the **notes list** (the app's home screen). Everything
below was verified statically (`flutter analyze` only) — this machine cannot
render the app, so these are the claims a static check cannot prove.

Skips the obvious. Each line is something that could plausibly be wrong and that
you would not notice unless you looked for it.

**Setup:** switch modes from **Settings → Theme**. You need both, and you need
three different note counts (see the last section).

---

## The two the mockup gets wrong

The design mockup shows a **gold note title** and a **gold "1 Note" count** in
dark mode. The spec deliberately overrides both. The wordmark *does* stay gold.

- [ ] **Dark:** the note card's title is **cream/off-white**, NOT gold
- [ ] **Dark:** the "1 Note" / "N Notes" count in the bottom bar is
      **cream/off-white**, NOT gold
- [ ] **Dark:** the "DistillEd" wordmark **is** gold — so wordmark and card
      title are visibly different colours in the same screenshot
- [ ] **Light:** wordmark, title and count all look like the same navy. Same hex
      on purpose — not a bug

## The blend between details and preview (the highest-risk item)

The details column on the left and the page preview on the right are meant to
read as **one surface that fades between them**, not two panels with a seam. The
wash is solid for the first 20% of the card, half gone by 44%, and fully clear by
72% — identical in both modes.

- [ ] **Both modes:** there is **no visible vertical seam** or hard edge where
      the details column meets the preview. If you can point at a line, the
      blend is too short
- [ ] **Both modes:** the page is faintly visible *behind* the right-hand part
      of the details column — that is intended, it is what "fadedly mixed" means
- [ ] **Light and dark look the same in how much they blend.** The dark
      thumbnail is dimmer overall (there is a scrim on the image), but the
      *fade* should have the same shape and reach in both
- [ ] **Critical — test with a LIGHT/BRIGHT thumbnail, not the dune image.**
      Open a note whose first page is mostly white. The note title must still be
      clearly legible, and so must the smaller grey date and page-count rows.
      **The grey meta rows are the first thing that will fail** — they sit
      furthest right, where the wash is thinnest. If they get hard to read,
      say so: the fix is a longer solid region, not a different text colour
- [ ] The wash does not reach so far right that the thumbnail looks washed out
      or pointless

## The card

- [ ] **Light:** card has a soft shadow, **no outline**
- [ ] **Dark:** card has a **1px hairline outline, no shadow**. A dark card with
      neither is the failure mode — look at the card edge against the page
- [ ] **Dark:** the thumbnail is visibly **darkened** compared to light mode.
      Same image file, painted over — if the dark card's photo glares as
      brightly as the light one's, the scrim is missing
- [ ] **Dark:** the scrim has not also dimmed the title area (the flat colour
      behind the text should be unaffected)
- [ ] Hovering / long-pressing a card still deepens its shadow in light mode

## The circular graph button (on the card's right)

- [ ] **Light:** white/surface circle with a **soft shadow**, no ring
- [ ] **Dark:** surface circle with a **1px gold ring** and **no shadow**
- [ ] **Both:** the button is clearly separated from the thumbnail behind it. If
      it disappears into the image in dark mode, the ring is not doing its job
- [ ] The glyph inside is gold in both modes

## Search field

- [ ] **Both:** fully rounded pill — the ends are semicircles, not soft
      rectangles
- [ ] **Light:** filled, with **no outline**
- [ ] **Dark:** filled **and** carrying a 1px hairline outline. Without it the
      field and the page behind it are only a few percent apart — if you cannot
      see where the field ends, the dark branch is wrong
- [ ] **Both:** the magnifying glass is **accent** (navy/gold); the placeholder
      text is grey. Two different colours, not one
- [ ] Type something — the clear (×) button appears and is **grey**, not accent
- [ ] Focus the field — the focus ring is accent-coloured

## Bottom bar

- [ ] **Both:** a 1px hairline runs along the **top edge** of the bar. Check it
      is visible in dark specifically
- [ ] **Both:** the bar is translucent — a card scrolling underneath is faintly
      visible through it, but the bar's own label stays readable
- [ ] **Light:** compose button is a navy rounded square with a **white** glyph
- [ ] **Dark:** compose button is a gold rounded square with a **dark, near-black**
      glyph. **Check the contrast direction** — a white glyph on gold would be
      the bug
- [ ] The filter/sliders icon on the left is accent in both modes

## Note counts — check all three

- [ ] **0 notes** (delete or trash everything): the empty state renders. Expect a
      large circular tinted disc with an accent glyph, a heading, and one line of
      guidance. It is **not** in the mockup — it was derived. Say whether it
      looks like it belongs
- [ ] **0 notes, dark:** the disc is visible against the page. If the disc and
      the background look identical, the tint is too subtle
- [ ] **Search with no matches** (type gibberish in the search field): a
      *different* empty state appears — magnifying-glass glyph, and the message
      quotes what you typed
- [ ] **1 note:** bottom bar reads "1 Note", singular
- [ ] **Many notes** (10+): cards scroll smoothly, the last card can scroll clear
      of the bottom bar, and every card's gradient/scrim renders the same way
- [ ] **Many notes, dark:** scroll fast. No flicker or missing scrim on cards
      entering the viewport

## Long titles

- [ ] Create a note titled something like
      **"A gratuitously long note title that will definitely not fit in here"**
- [ ] The title wraps to **at most 2 lines** and ends in an ellipsis (…)
- [ ] The thumbnail does **not** get pushed, squeezed, or resized — the flat
      text region stays exactly the same width as on a short-titled card
- [ ] No yellow-and-black overflow stripes anywhere
- [ ] Check in **both** modes

## Preview tints and the removed duplicate title

Two things changed here after the first review pass.

- [ ] Make 4+ notes with no drawn content. Their preview areas should show
      **different background tints** (lavender, sand, mauve, blush, teal, slate,
      sage — rotating). A list where every preview is the same colour means the
      tints did not come back
- [ ] Reopen the list — each note keeps the **same** tint it had before. The
      tint is derived from the note's id, so it must not shuffle on rebuild
- [ ] **Dark:** the tints are dark, muted versions — not the pastel light-mode
      set. If a lavender pastel shows up on a dark card, the dark tint set is
      not being used
- [ ] **The note name appears exactly ONCE per card** — in the details column on
      the left. It must **not** also appear large in caps over the preview area.
      Check a note with no drawn page, which is where the duplicate used to be
      most obvious
- [ ] A note with no drawn page **and** no recognised text shows just the tinted
      area — no text at all. That is intended

## Icons

Icons were swapped from Material to Phosphor to match the settings pass.

- [ ] Every icon rendered — no empty squares. Check: wordmark row overflow (…),
      search glass, clear ×, card calendar, card page, pin marker on a pinned
      note, graph button, bottom-bar sliders, compose button
- [ ] The graph button shows the original **six-node hub** glyph. It is
      deliberately the only Material icon left on this screen — Phosphor has no
      equivalent that reads as a node graph at this size
- [ ] Pin a note — the pin marker appears above the title and is **accent**

## Not done in this pass — expect these to look wrong

Out of scope; do not report as regressions.

- [ ] The **sort sheet**, **note actions sheet** (long-press a card), **delete
      confirmation** and **new-note dialog** are still on the OLD palette.
      Deferred to the straggler sweep after all four screen passes
- [ ] The **note editor**, **trash** and **about** screens are still on the old
      palette. Only settings and home are migrated so far
- [ ] Destructive actions ("Delete note") are still coral red — the nine-token
      spec has no destructive colour

---

## If something is wrong

Note which checkbox, which mode, and whether it is a colour or a layout problem.
Colours trace to `lib/core/theme/app_colors.dart`. The card's flat-text region is
`_ReadabilityGradient` in `note_preview.dart`; its width is driven by
`NotesPalette.overlayWidthFactor`.
