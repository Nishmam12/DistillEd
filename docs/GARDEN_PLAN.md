# Margo — The Garden (gamification plan)

**Status: proposed, not approved.** Written 2026-11-13 as a later phase
(roadmap Phase I). Nothing here is built yet. It is kept in the repository so
the planning is reviewable alongside the code. Open decisions are listed at the
end of the plan.


Added 2026-11-13. **A later phase: nothing here is to be built until the user
says so.** Planned now so it fits the architecture when its turn comes.
Recommended slot: after Phases B and C (writing and navigation parity), and
after Learning Memory and the knowledge graph have been validated on a device,
because the garden is drawn from that data.

## Context

The user wants Margo to reward studying the way Forest-style focus apps
reward focus time: calm, nature-themed, something that grows, fun enough to
bring people back, and able to carry paid cosmetic content later. Direction
given: **a garden or small farm, not a room to decorate; calm and relaxing;
simple first; animals later** because they need far more art and logic.

Margo's advantage over a focus timer is that it already measures learning,
not just time: `ConceptMastery` (unseen → learning → practiced → mastered),
flashcard reviews with due dates, graded quiz attempts, study-plan days. The
plan uses that so the garden is **a picture of what you know**, which a
generic to-do garden cannot copy.

## The concept in one paragraph

Every notebook is a **garden bed**. Every concept in it is a **plant**, and
the plant's growth stage *is* the concept's mastery level: seed, sprout, bud,
bloom. Studying produces **sunlight**, the one currency. A plant droops when
its concept is due for review and perks up when you review it; it never dies.
Sunlight buys decorative things: ornamental plants, paths, ponds, lanterns,
garden themes. Growth itself can never be bought. Later loops add harvests
(the "small farm"), visiting creatures, and study mini-games.

## Design principles (the non-negotiables)

1. **Learning drives growth; money and time cannot.** Nothing paid speeds up a
   plant, repairs a streak, or grants sunlight.
2. **Calm, never punishing.** Plants droop, they do not die. A missed day
   costs nothing but the day. No countdown pressure, no red badges.
3. **Never on the canvas.** No pop-ups, confetti or counters while writing.
   Rewards appear when a session ends and on the garden screen.
4. **Optional.** One switch turns the whole layer off; the app is then exactly
   the notebook it is today.
5. **Offline and private.** No account, no server, no analytics dependency.
6. **Content is data.** A new plant pack is art plus a catalogue entry, not
   code.

## The core loop

| You do | The garden does |
| --- | --- |
| Meet a new concept in your notes | A seed appears in that notebook's bed |
| Review due flashcards, pass quiz questions | The matching plants grow a stage; drooping ones recover |
| Finish a focus session, a study-plan day | You earn sunlight |
| Keep a daily habit | A streak ("days tended") raises your gardener rank, unlocking space |
| Spend sunlight | Decor, ornamental plants, themes |

### What earns sunlight (starting numbers, to be tuned)

| Action | Sunlight | Daily cap | Source of truth |
| --- | --- | --- | --- |
| Focus session finished (per 25 min) | 10 | 80 | New focus timer |
| Flashcard reviewed on or after its due date | 2 | 60 | `review_notifier.dart` |
| Quiz finished; +1 per correct answer | 5 + n | 3 quizzes | `quiz_sheet.dart:271` (`recordQuizAttempt`) |
| Study-plan day ticked | 15 | 1 | `study_planner_notifier.dart:78` (`setDayCompleted`) |
| Page of notes written (recognised text grew by 40+ words) | 5 | 20 | `PageTextRecord` length delta |
| Concept reaches "mastered" (once per concept) | 20 | none | `ConceptMastery` transition |
| First study action of the day | 10 | 1 | streak |

Caps exist so nobody farms sunlight by scribbling or reopening a note.

### Streak and rank

- **Days tended**: a day counts when any capped action above happened.
- **Rain day**: one missed day a week is forgiven automatically (it rained;
  the garden was fine). Never sold.
- **Gardener rank** comes from lifetime sunlight and unlocks more beds,
  larger plots and free plant species. Ranks never go down.

### Drooping (the gentle return hook)

`LearningMemoryRepository.dueForReview` already says which concepts are due.
Those plants are drawn drooping, and the garden shows "6 plants need water"
with a button straight into the existing review screen (`/note2/:id/review`).

## Later loops, in order

1. **Harvest (the small farm).** A bloom whose reviews are kept up yields a
   harvest every few days: flowers, fruit, vegetables by species. Harvests
   fill a **field journal** (collection book) and convert to sunlight. This is
   what makes long-term retention pay, not just first-time learning.
2. **Seasons and weather.** The garden follows the real season and time of
   day. Pure atmosphere, no mechanics.
3. **Visitors (the first animals).** Butterflies, bees, birds, a hedgehog
   appear when the garden is varied or a streak is long, and are recorded in
   the journal. They need no care logic, so they are cheap: one sprite and one
   appearance rule each.
4. **Study mini-games.** Built from the user's own flashcards: match pairs
   ("seed sorting"), timed recall ("watering round"), link related concepts
   (uses `ConceptRelation`). They count as review, so they grow plants.
5. **Kept animals** (hens, a pond with fish, bees giving honey). Real care
   and production logic plus a lot of art. Last, and only if the earlier
   loops prove people stay.

Other ideas considered and left out for now: a forest (most copied, no link
to notes), an aquarium or terrarium (good alternatives if the garden art
proves too costly; the same engine would drive them), friends and
leaderboards (needs accounts, a server and moderation; none exists).

## Architecture

Follows the existing feature shape (`lib/features/<name>/{domain,data,
presentation}`, pure rules in `domain/`, Isar records that only convert,
Riverpod providers) and the existing "observe, never own" rule the AI layer
uses: **the garden reads study activity; no study feature depends on the
garden.**

```
study features ──record(event)──▶ StudyEventLog ──▶ RewardEngine ──▶ GardenState
(review, quiz, plan,              (append-only,      (pure: caps,      (wallet, streak,
 focus, notes, mastery)            de-duplicated)     streak, rank)     inventory, layout)
                                                                             │
ConceptMastery (read-only) ───────────────────────────────────────────▶ GardenView
Catalogue (JSON asset) + Entitlements (earned ∪ purchased) ─────────────────┘
```

### New module: `lib/features/garden/`

| Layer | Files | Role |
| --- | --- | --- |
| domain | `study_event.dart` | `StudyEvent {kind, at, notebookId, amount, dedupeKey}`. Kinds stored as text so an unknown one is ignored, as `MasteryLevel.storageKey` does. |
| domain | `reward_engine.dart` | Pure function: events for a day + rules → sunlight granted, with caps. All numbers in one `RewardRules` constant. |
| domain | `streak.dart` | Days tended, rain day, clock-rollback guard. Pure. |
| domain | `garden.dart` | `Plant` (derived from `ConceptMastery`: stage, drooping, species), `GardenBed`, `PlacedItem`, rank thresholds. |
| domain | `catalogue.dart` | Items, packs, prices, unlock rules; parsed from an asset. |
| domain | `entitlements.dart` | `EntitlementStore` interface: which packs are owned. |
| data | `study_event_record.dart`, `garden_state_record.dart`, `garden_item_record.dart` | Three Isar collections (see Storage). |
| data | `garden_repository.dart` | Reads and writes; exposes streams for the UI. |
| presentation | `garden_providers.dart`, `garden_screen.dart`, `garden_painter.dart`, `focus_session_controller.dart`, `session_summary_sheet.dart`, `garden_shop_sheet.dart`, `field_journal_screen.dart` | UI. |

### Recording activity: one door in

A single `studyEventsProvider` with `record(StudyEvent)`. Each hook is one
fire-and-forget line that can never throw into its caller (same contract as
`ContextEngineNotifier._notifyContent`):

| Hook | Where |
| --- | --- |
| Card reviewed | `lib/features/ai/presentation/flashcards/review_notifier.dart` |
| Quiz graded | `lib/features/ai/presentation/quiz/quiz_sheet.dart` beside `recordQuizAttempt` |
| Plan day ticked | `lib/features/ai/presentation/study_planner_notifier.dart` (`setDayCompleted`) |
| Notes written | where `pageTextStore.save` is called in `ai_providers.dart` (`pageContextProvider.onContent`) |
| Concept mastered | `IsarLearningMemoryRepository._putConcept`, on a level change |
| Focus session | the new `focus_session_controller.dart` |

Every event carries a **dedupe key** (`review:<cardId>:<yyyy-mm-dd>`,
`quiz:<attemptId>`, `plan:<planId>:<dayIndex>`), so a retry, a rebuild or a
restored backup can never pay twice. The log is append-only, which gives
three things for free: rewards can be recomputed if the rules change, a bug
can be audited, and a future sync merges by key (the same "natural key"
approach `concept_mastery.dart` documents).

### Plants are derived, not stored

A plant is computed from `ConceptMastery` each time the garden opens
(`LearningMemoryRepository.allConcepts`, `dueForReview`). Nothing about
growth is duplicated in the garden's tables, so the garden cannot disagree
with what the app believes you know. Species and plot are a deterministic
function of `conceptKey` unless the user has replanted or moved it, and only
those overrides are stored.

### Storage (a schema change: stop and ask before building)

Three collections added to `_schemas` in `lib/main.dart`, each with a
migrator test:

| Collection | Holds |
| --- | --- |
| `StudyEventRecord` | The event log. Indexed by day and by dedupe key. Old days are compacted to a daily summary after 90 days. |
| `GardenStateRecord` | One row: sunlight, lifetime sunlight, streak, rain-day state, last-seen clock, settings. |
| `GardenItemRecord` | Owned items, placed decor (item id, bed, position), species and position overrides. |

No existing collection changes. All enums are stored as text.

### Backup

Phase E archives are per notebook; garden progress is global. The backup
service writes one extra file, `margo-garden.json`, to Downloads/Margo
(state, items, and the event log's daily summaries) and restores it with the
notebooks. Notebook ids are remapped on restore, so garden rows reference
notebooks through the same remap `NotebookArchive.remappedTo` already does.
Purchases are never in a backup; they restore from the store account.

### The focus timer

- Started from the editor's app bar: 25 / 45 / custom minutes, optional
  break. A thin ring in the app bar is the only thing visible while writing.
- A session counts when the editor stayed in the foreground for its length.
  Leaving the app for more than 30 seconds ends it without reward and without
  penalty. Uses the app-lifecycle approach `backupLifecycleProvider` has.
- On finish: a quiet summary sheet (minutes, sunlight earned, which plants
  grew), with "Visit garden".
- Sessions are also where ambient soundscapes play (`just_audio` is already
  a dependency).

### Rendering

- A dedicated route `/garden`, reached from the home screen (a card beside
  `knowledge_graph_button.dart`) and from the session summary. Nothing runs
  in the editor.
- Flutter `CustomPainter` over a simple plot grid, with PNG or SVG sprites
  (`flutter_svg` is present) and light implicit animation (sway, drift).
  **No game engine dependency** for the first versions. If kept animals are
  ever built, revisit Flame then.
- Honour reduced-motion. Cap drawn plants per bed (about 60); the rest show
  as a meadow patch that expands on tap, so a 500-concept notebook stays
  fast.

### Catalogue and entitlements

- `assets/garden/catalogue.json` lists every item: id, kind (species, decor,
  theme, sound), sunlight price, pack id, unlock rule (rank, achievement,
  free). Packs list a store product id when they are paid.
- "Owned" = earned or bought with sunlight (in `GardenItemRecord`) ∪ packs
  the `EntitlementStore` reports. The first implementation returns "nothing
  purchased"; the store-backed one arrives with monetization. The garden code
  never knows which it is talking to.

## Monetization

Built in a later sub-phase, but the catalogue and entitlement seams above
exist from the first version so nothing is reworked.

**Recommended model: one-time cosmetic packs plus an optional supporter
subscription.** (Open decision, see the end.)

| Sold | Examples |
| --- | --- |
| Plant packs | Alpine flowers, orchard trees, herbs, succulents, night-blooming set |
| Garden themes | Japanese garden, cottage garden, desert, moonlit, greenhouse |
| Decor sets | Stone paths, ponds, lanterns, trellises, scarecrows |
| Soundscapes | Rain, stream, dawn chorus, wind in trees |
| Matching stationery | Notebook covers, paper styles and ink colour sets in each theme |
| Supporter subscription | Every pack, one exclusive plant a month, early access to new themes |

Rules that keep it fair, and keep store reviews kind:

- **Never sold:** sunlight, growth, streak repair, rain days, anything random.
  No loot boxes: paid content is always shown before purchase.
- The free garden is complete on its own: about 12 species, 2 themes, a
  starter decor set, all earnable.
- Every paid item has a free cousin, so a free garden never looks unfinished.
- Regional pricing and a student-priced bundle.

Technical: Google Play Billing through `in_app_purchase` (**a new
dependency: stop and ask**), products defined in Play Console, purchases
verified on device, "Restore purchases" in Settings. With no backend there is
no server-side receipt check; acceptable for cosmetics, and noted as a known
limit.

## What makes it fun (beyond points)

- **Agency:** replant a concept as any species you own; arrange decor; name
  the garden.
- **Surprise that is earned:** a free seed packet with a random species at
  rank-ups and long streaks.
- **Collection:** the field journal of species grown, harvests and visitors,
  with a line about each.
- **Visible progress that means something:** a bed in full bloom is a subject
  you know. Tapping a plant opens its concept: definition, the page it came
  from, a "review now" button.
- **A weekly recap card** (minutes focused, concepts grown, a picture of the
  garden) that can be shared with `share_plus`. No account needed.
- **Quiet craft:** small sounds and haptics on watering and harvest, a day and
  night cycle, weather.

## Risks and how the plan handles them

| Risk | Handling |
| --- | --- |
| Art is the real cost: every species needs four growth stages | Start with 12 species (48 sprites) in one consistent style. **Art source is an open decision.** |
| Rewards farmed by trivial actions | Daily caps, dedupe keys, notes counted by recognised words not strokes |
| Changing the device clock to fake streaks | A day earlier than the last recorded one earns nothing and does not move the streak |
| The garden distracts from studying | Lives on its own screen; the only way to grow plants is to study |
| A broken mastery pipeline makes an empty garden | Gate the phase on device validation of Learning Memory; sunlight and decor still work without concepts |
| Notification fatigue | At most one reminder a day, off by default, quiet hours. Needs `flutter_local_notifications` (**new dependency: stop and ask**) |
| Database growth from the event log | Compaction to daily summaries after 90 days |
| Younger users and store policy | No random paid rewards, no social features, no data leaves the device |

## Build order

Each step ends with analyze clean, tests green, a summary, and a stop. One
step per session.

| Step | What | Model |
| --- | --- | --- |
| I0 | Art direction: pick style and source; produce the first 12 species, ground tiles, 2 themes. No code. | — |
| I1 | Engine with no UI: events, reward rules, streak, rank, repository, the three collections (after schema sign-off), hooks into the six sources. Fully unit-tested. | Opus 5.5 |
| I2 | Focus timer in the editor and the session summary sheet. | Sonnet 5.5 |
| I3 | Garden screen: beds and plants from `ConceptMastery`, drooping, tap a plant to open its concept, entry card on the home screen, master switch in Settings. | Opus 5.5 |
| I4 | Shop and inventory with sunlight, placing decor, catalogue asset, replanting. | Sonnet 5.5 |
| I5 | Backup of garden progress; weekly recap card and sharing. | Sonnet 5.5 |
| I6 | Harvest loop and the field journal. | Sonnet 5.5 |
| I7 | Seasons, weather, day and night; soundscapes during focus. | Sonnet 5.5 |
| I8 | Visitors. | Sonnet 5.5 |
| I9 | Store: billing dependency (after sign-off), paid packs, supporter subscription, restore purchases. | Opus 5.5 |
| I10 | Study mini-games, one per session. | Sonnet 5.5 |
| I11 | Daily reminder notification (after dependency sign-off). | Sonnet 5.5 |
| I12 | Kept animals. Re-plan before starting. | Opus 5.5 |

**First shippable version = I0 to I5.** I6 to I8 are what keep people after
the first fortnight. I9 should wait until there is a garden people already
like.

## Verification

- **Reward engine:** unit tests for every rule, every cap, dedupe (the same
  event twice pays once), the streak across midnight, time-zone change and
  daylight saving, the rain day, clock rollback.
- **Derivation:** a `ConceptMastery` list in → the expected plants, stages and
  drooping out; a mastery demotion shrinks the plant.
- **Hooks:** widget tests that reviewing a card, finishing a quiz and ticking
  a plan day each write exactly one event, and that a throwing garden never
  breaks the study feature.
- **Storage:** migrator test for the three collections; backup round trip
  including notebook id remap; restore twice does not double sunlight.
- **Rendering:** golden tests of the garden painter for each stage and theme,
  and with reduced motion.
- **On device:** a 500-concept notebook opens the garden without dropped
  frames; a focus session survives screen-off and ends on leaving the app;
  with the master switch off, no garden code runs and no events are written.
- **Feel:** a two-week self-test by the user before I9, with the reward
  numbers tuned from the event log.

## Open decisions for the user

1. **Art source and style** (I0): commissioned illustrator, a licensed asset
   pack, or generated art cleaned up by hand; flat vector or soft painted.
   Nothing else can start meaningfully without this.
2. **Monetization model:** packs plus supporter subscription (recommended),
   packs only, or decide after launch.
3. **Mini-games:** study games from the user's own cards (recommended), or
   none.
4. **Sharing:** shareable recap cards with no accounts (recommended), or
   strictly private.
5. **Names:** "sunlight", "days tended", "rain day", "field journal" are
   working names.
