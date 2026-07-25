# Update for Notes Screen

I want you to implement the **Notes List Screen**.

This is **NOT** a traditional list and **NOT** a grid.

The inspiration is a combination of: - Apple's Notes app (clean,
minimal, lots of whitespace) - A modern document browser -
Glassmorphism/card overlay design

The UI should feel premium, like an iOS application, while still
following Flutter best practices.

## General Design

The screen contains: - Large title ("Notes") - Search bar - Scrollable
list of notes - Floating create button - Filter button

Background: **#F7F8FA**. Use generous whitespace, soft shadows, and
smooth animations.

## Note Card Design

Each note is displayed as **one large horizontal card**.

-   Show approximately **5--6 cards on screen** without scrolling.
-   Card height: **150--170 px** (responsive).
-   Outer radius: **22 px**
-   Soft shadow (blur \~20, opacity \~10%).

## Layout

The card is one seamless component.

-   The **right 65--70%** is the live preview (image or text).
-   The preview is **NOT** a separate card.
-   The **left 30--35%** is a frosted glass overlay sitting on top of
    the preview.
-   No gap between overlay and preview.
-   Only the left side has rounded corners; the edge touching the
    preview is perfectly straight.

The preview should continue underneath the overlay with a subtle
left-to-right white gradient to improve readability.

### Left Overlay

Use BackdropFilter (sigmaX/Y ≈ 8).

Inside: - Large note title - Creation date - Page count

Typography: - Title: 20, SemiBold - Metadata: 14, Medium, grey

The overlay itself casts a soft shadow over the preview.

### Right Preview

Display either: - Full-height image filling the preview area - Text
snippet/checklist/bullets

The preview fills the entire right side seamlessly.

### Knowledge Graph Button

A floating circular button overlapping the preview.

-   White circle
-   Radius \~26
-   Strong soft shadow (elevation-like)
-   Modern network icon

It should feel like it is floating above the card.

## Card Size & Spacing

The UI should not feel dense.

-   Card height: **150--170 px**
-   Use `ListView.separated`
-   Vertical spacing between cards: **16 px**
-   Horizontal padding: **18 px**
-   Top padding: **20 px**
-   Bottom padding: **120 px** (for FAB)

Aim to display: - 5 full cards - or 5 full cards + part of a sixth

Avoid tiny, cramped list items.

Recommended layout:

``` dart
ListView.separated(
  padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
  itemCount: notes.length,
  separatorBuilder: (_, __) => const SizedBox(height: 16),
  itemBuilder: (_, index) {
    return SizedBox(
      height: 160,
      child: NoteCard(note: notes[index]),
    );
  },
);
```

## Header

-   SafeArea
-   Large "Notes" title
-   Font size 38
-   Bold

## Search Bar

-   Height 52
-   Rounded
-   Leading search icon
-   Material 3 styling

## Bottom Controls

-   Floating compose button (bottom-right)
-   Filter button (bottom-left)

## Animations

Use: - AnimatedContainer - AnimatedScale - AnimatedOpacity - Hero - Fade
transitions

Hover (desktop): - Scale 1.01 - Slight lift - Slightly stronger shadow

## Flutter Requirements

Create reusable widgets:

-   NotesScreen
-   SearchBarWidget
-   NoteCard
-   NoteOverlay
-   NotePreview
-   KnowledgeGraphButton

Use responsive layouts only. Avoid hardcoded widths.

## Sample Model

``` dart
class Note {
  final String title;
  final DateTime createdAt;
  final int pages;
  final NoteType type;
  final String previewImage;
  final String previewText;
  final bool pinned;
}
```

## Color Palette

-   Background: #F7F8FA
-   Cards: #FFFFFF
-   Primary Text: #111111
-   Secondary Text: #7A7A7A
-   Accent: #192841
-   Shadow: Colors.black.withOpacity(0.08)

## Overall Feel

Think: - Apple Notes × Notion - Apple Photos document browser - Arc
Browser - Linear

The UI should look polished enough for Dribbble or Behance, emphasizing
typography, whitespace, subtle shadows, glass overlays, and elegant
motion.
