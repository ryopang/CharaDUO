---
title: Fun Duo Party Game — PRD v1
date: 2026-09-22
tags: [product-management, prd, ios-development, iphone-duo]
status: ready-for-development
supersedes: DUO PRD Draft
working_title: "Fun Duo Party Game" (placeholder — see §12.1)
---

# Fun Duo Party Game — Product Requirements v1

A native iOS charades party game built for iPhone Duo's tabletop posture. The
describer reads words on the vertical inner half; the guessers watch a
scoreboard on the outer display, while the outer-facing cameras and the
microphone record their reactions into a highlight reel, played back — optionally
at 2× or 3× — at the end of the match.

**Platform:** iOS 27.1+ · Xcode 27.1 · SwiftUI · Swift 6 strict concurrency
**Hero device:** iPhone Duo (7.6" inner / 5.4" outer, ships 2026-10-23)
**v1 monetization:** free, no IAP — but architected for it (§9)

---

## 1. Ground truth: what the SDK actually allows

Every claim below was verified against the installed iOS 27.1 SDK headers, not
documentation or blog posts. **Do not design around anything not on this list.**

### 1.1 Confirmed available

| API | Module | Purpose here |
|---|---|---|
| `onHingeChange(isEnabled:_:)` → `DeviceHingeContext` | SwiftUICore | Detect tabletop posture, hinge angle |
| `GeometryProxy.reservedRegions(kind:options:)` → `ReservedRegion` | SwiftUICore | Locate the fold crease to split the inner display |
| `.sceneAccessory { CameraCaptureAccessory(...) }` | SwiftUI | Outer-display content |
| `.onAvailabilityChange { }` | SwiftUI | React to the system granting/revoking the outer display |
| `UISceneAccessory.cameraCapture(sceneConfiguration:)` | UIKit | UIKit equivalent, if ever needed |
| `UISceneAccessoryRegistration.isAvailable` (read-only) / `.isEnabled` (read-write) | UIKit | System controls availability; we control only whether we draw |
| `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)` | AVKit | Resolve which cameras face the guessers, live as the device folds |
| `AVCaptureDeviceDirectionMap.forwardFacingDeviceDescriptors` | AVKit | The cameras pointing at whatever is in front of a given view |
| `AVCaptureDeviceTypeBuiltInOuterUltraWideCamera` / `...InnerUltraWideCamera` | AVFoundation | Duo's two camera clusters |
| `AVCaptureSession.systemPressureCost` | AVFoundation | Thermal budget monitoring during long rounds |
| `AVAudioTimePitchAlgorithmVarispeed` | AVFoundation | 2×/3× speed-up with pitch shift |
| `UIHingeInteraction`, `UIHinge`, `UIHingeStatus` | UIKit | UIKit hinge equivalent (not needed; SwiftUI path is complete) |
| `ArrangementView` / `UIArrangementViewController` | SwiftUI / UIKit | Adaptive two-pane container (used in setup, not gameplay) |

### 1.2 Confirmed NOT available — architectural hard limits

1. **There is no general API to draw on the outer display.** No second
   `UIScreen`, no arbitrary secondary window. Apple: *"New windows cannot be
   created. That behavior is reserved for the inner display."* The only route is
   a scene accessory.
2. **The only Duo scene accessory is `cameraCapture`**, which requires the app
   foregrounded, full-screen on the inner display, **and an active
   `AVCaptureSession`.** No camera session means no outer display.
3. **Availability is system-controlled and revocable at any moment.** From
   `UISceneAccessory.h`: *"Scene accessories enhance the app's experience when
   available, but the app must remain fully functional without them. The system
   decides when and where to present it."*
4. **There is no Duo device-capability key.** The app cannot be restricted to
   iPhone Duo in the App Store. Assume App Review tests on a non-Duo iPhone.

> **§1.2.3 and §1.2.4 are the two constraints that shape this entire document.**
> The outer display is an *enhancement layer*. The game must be complete and
> satisfying without it, and it must degrade mid-round without interrupting play.

### 1.3 Camera geometry — do not hardcode

The draft assumed "outer cameras facing down on a tabletop." Do not assume this.
Instantiate `AVCaptureDeviceDirectionCoordinator` against the **outer accessory
scene's root view** and read `forwardFacingDeviceDescriptors` — those are, by
definition, the cameras pointed at the guessers, recomputed as the hinge moves.
If that array is empty, disable capture and fall back (§5.5).

---

## 2. Product definition

### 2.1 The core loop

1. One player is the **describer** and stands or sits at the vertical inner half.
2. Their team are the **guessers**, on the opposite side, facing the outer display.
3. A word appears on the vertical half. The describer conveys it — by talking,
   by miming, or both — without saying the word itself.
4. Describer taps **Correct** or **Skip** on the flat tabletop half, without
   looking down — hit zones are half the flat surface each, with distinct haptics.
5. Timer expires → round summary → device passes to the next team.

**Both play styles are supported. Nobody has to sit down.** The device rests on
any surface — table, counter, shelf — and players on either side may stand. The
only physical requirement is that the describer can reach the flat half to tap.

This has two design consequences:

- **Hit zones are sized for a standing reach, not a seated one.** A standing
  describer taps at arm's length and at an angle, so the two zones occupy the
  full flat half with no margins, dead space, or competing controls. Blind
  tapping must survive an imprecise, angled stab.
- **The rules text offers both styles rather than prescribing one.** Quick Play
  says "describe it or act it out." Mimed play works when the describer stands;
  verbal play works seated. Let the group choose.

### 2.2 Match structure

- 1–4 teams. Default 2.
- **Fixed rounds:** each team describes an equal number of times. Default 3
  rounds each; configurable 1–5.
- Running total carries across rounds. Highest total at the end wins.
- **Time Limit mode only in v1.** Round length 30 / 60 / 90 / 120s, default 60s.
- Target Mode (race to N words) is **deferred to v2**.

### 2.3 Scoring

- Correct = +1.
- Skip = 0 by default. A **Skip Penalty** toggle (default off) makes it −1.
- No word repeats within a match. Draw from a shuffled deck built at match start
  across all selected categories; if the deck empties, reshuffle excluding the
  current round's words and surface a subtle "deck reshuffled" note.

### 2.4 The 30-second setup promise

The setup flow must reach "first word on screen" in under 30 seconds. Enforce by:

- **Quick Play** is the primary button on the home screen. One tap → 2 teams
  ("Team 1"/"Team 2"), all 9 categories, 60s, 3 rounds, last-used language.
  No naming, no toggles.
- Everything else lives behind a secondary **Custom Game** path.
- Team names are optional throughout. Never block on text entry.
- **Acceptance test:** from cold launch, Quick Play to first word in ≤ 5 taps
  and ≤ 30s wall-clock, including camera permission if already granted.

---

## 3. Posture and layout

### 3.1 Postures

| Posture | Detection | Behavior |
|---|---|---|
| **Tabletop (target)** | `DeviceHingeContext` angle ≈ 75–115°, device roughly level | Full two-sided experience |
| **Flat / fully open** | angle ≈ 180° | Single-screen layout, outer display unavailable, game fully playable |
| **Folded shut** | `.closed` | Pause match, show resume affordance on wake |
| **Non-Duo iPhone** | No hinge context | Single-screen pass-the-phone mode (§8) |

**No auto-pause on posture change.** Per the decision to cut it: a party game
gets jostled constantly and false pauses are worse than the problem they solve.
The *only* posture event that pauses is `.closed`, which is unambiguous intent.
If the device leaves tabletop mid-round, the layout reflows and play continues.

### 3.2 Inner display, tabletop posture

Split at the crease using `reservedRegions(kind: .division)`. Never hardcode a
50/50 split or a pixel offset — read the actual reserved region and lay out
around it.

**Vertical half (the "lid") — describer-private:**
- The target word, maximum legible size, vertically centered.
- Category label, small, above the word.
- Countdown timer as **descending digits**, subordinate to the word.
- Urgency gradient: **restrained on this surface only** — a colour wash behind
  the word would fight its legibility, which is this half's entire job. Apply the
  gradient to the timer's own container and a thin border inset, not the full
  background. The other two surfaces (§3.2 far edge, §3.4) carry the full wash.
- Nothing else.

**Flat half (on the table) — shared surface, split by distance:**
- **Near edge (describer side):** two full-width hit zones, 50% each, Correct
  (top, toward the crease) and Skip (bottom, toward the player). Large, high
  contrast, designed for blind tapping.
- **Far edge:** timer and live score, **rotated 180°** so it reads right-side-up
  to the guessers across the table. Full urgency gradient (§3.3).
- Rotating the far edge is what makes the flat half serve both audiences at
  once. It is the signature layout idea of this app — get it right.

### 3.3 Countdown treatment

The timer is always **descending digits** — the literal seconds remaining, never
a bare progress bar or ring. Digits are the primary, unambiguous channel.

Behind the digits, the background transitions continuously **green → amber → red**
as the round runs out. Amber is not decoration: a direct green→red ramp is the
single worst choice for the ~8% of men with red-green colour vision deficiency,
and passing through amber keeps the midpoint distinguishable.

| Remaining | Treatment |
|---|---|
| 100%–50% | Green, static |
| 50%–20% | Continuous interpolation green → amber |
| 20%–0% | Continuous interpolation amber → red |
| Final 10s | Red, plus a per-second pulse in sync with the haptic tick (§10.4) |

Rules:
- The interpolation is **continuous**, driven off the same monotonic clock as the
  digits (§10.3) — never stepped per second, and never animated independently of
  real elapsed time.
- **Colour is never the only cue.** Digits carry the state, the final-10s pulse
  adds motion, and the haptic tick adds touch. A player who sees no colour
  difference at all loses nothing.
- Under **Reduce Motion**, drop the pulse and keep the colour ramp.
- Maintain WCAG AA contrast for the digits against every point of the gradient —
  the digit colour shifts along with the background to hold that ratio.
- Under **Increase Contrast**, replace the gradient with three flat colour steps.

### 3.4 Outer display (guessers) — enhancement layer

Rendered via `.sceneAccessory { CameraCaptureAccessory { ... } }`.
**Passive, no touch input in v1.**

- Current category, large.
- Countdown digits, large. **Full urgency gradient (§3.3)** — this is the surface
  the whole room watches, so it carries the treatment at full strength.
- Team name and live score.
- Live camera mirror, small and inset, with a recording indicator when capture
  is active.

When `onAvailabilityChange` reports unavailable, this content simply stops being
presented. **Nothing in the game state depends on it.** Do not show an error, do
not pause, do not surface a "reconnect" prompt mid-round.

---

## 4. Round summary and match end

### 4.1 Round summary (after each round)

- Team's score this round and running total.
- Expandable list of every word encountered, colour-coded Correct / Skipped.
- If a highlight clip was captured: an inline player (§5.4).
- "Next team" primary action.

### 4.2 Match end

- Final standings, winner celebration.
- **Reaction reel:** all rounds' clips, playable per-round.
- **Save prompt:** explicit "Save to Photos" per clip or for the whole reel.
- **Anything not saved is deleted when the match-end screen is dismissed.**
  This is a hard requirement, not a cleanup nicety (§7.2).

---

## 5. Reaction camera

### 5.1 Purpose

Two jobs, in this order of importance:
1. **A real feature** — the round-end highlight reel of the guessing team.
2. It is what makes the outer display legally available at all (§1.2.2).

This ordering matters for App Review. The camera is not a trick to unlock a
scoreboard; it produces a user-visible artifact the player can watch and save.

### 5.2 Capture configuration

**The guessing team only, with sound.** A single `AVCaptureSession`.

- **Video:** the cameras in `forwardFacingDeviceDescriptors` relative to the
  **outer** accessory scene view — by definition, whatever is in front of the
  outer display. 720p30, capped.
- **Audio:** single microphone input, mono, 44.1kHz. This captures the whole
  table — the describer's voice as well as the guessers' — so the reel still
  carries both sides of the exchange even though only one side is on camera.
- Capture runs only during an active round. Tear the session down at round end.

**The describer is deliberately not filmed.** In tabletop posture the inner
camera sits on the lid at close range, framing the describer's torso at best,
and misses them entirely when they stand to mime. A second feed would add a
multi-camera session, roughly double the thermal load, and introduce a hardware
dependency that cannot be verified without the device — all to produce footage
that is not worth watching. Audio already carries the describer's performance.

### 5.3 Capture states

Three states, resolved at match start. Each degrades silently:

| State | Condition | Result |
|---|---|---|
| **Full** | Camera + microphone granted | Reel with sound. Outer display active. |
| **Silent** | Camera granted, microphone denied or audio toggled off | Reel without sound. Outer display active. |
| **None** | Camera denied | No reel, no outer display. Game plays normally. |

The outer display requires a **video** capture session, not audio — so denying
the microphone costs you sound on the reel and nothing else.

Observe `systemPressureCost` throughout a round. If it climbs under thermal
load, step down to 540p, then shorten the rolling buffer, then drop to **None**
rather than letting the timer stutter. Gameplay smoothness outranks the reel.

### 5.4 Export is deferred, not live

Nothing is assembled during capture. Retain the rolling buffer, and build the
finished clip only when the player taps Save.

Concatenation and speed scaling during a round would add a render pass over the
exact 60 seconds the countdown must stay perfectly smooth. Deferring it moves
that cost to an idle moment and makes the speed options (§5.6) essentially free.

### 5.5 Highlight selection

Do not keep the full round. Retain a rolling buffer and extract a window around
each **Correct** event — the moment of the guess is the funny part.

- 2.5s window per correct answer: 1.5s before the tap, 1.0s after.
- Cap at 6 clips per round, evenly sampled if there were more.
- Concatenate into one round clip, ≤15s at 1×.

### 5.6 Playback and speed options

Inline on the round summary: muted by default, looping, tap to expand and unmute.
Never autoplay full-screen. Never block the "Next team" action.

On **Save**, offer **1× / 2× / 3×**:

- Implemented with `AVMutableComposition.scaleTimeRange(_:toDuration:)`, applied
  at export only. The captured footage is always 1×; speed is a render parameter,
  so the choice is reversible and costs nothing until Save.
- Audio uses **`AVAudioTimePitchAlgorithmVarispeed`** — pitch rises with speed.
  This is deliberate. Pitch-corrected audio at 3× sounds clinical; chipmunked
  audio is the joke. Do not "fix" this.
- Default the picker to **2×**, the funniest setting for reaction footage.
- Preview updates live in the player as the player changes speed, so the choice
  is made by watching rather than guessing.

### 5.7 Failure handling

Capture is best-effort. Any of these means "no reel this round," silently:
- Camera permission denied (microphone denial only costs sound — §5.3)
- `forwardFacingDeviceDescriptors` empty
- Session interrupted (call, Control Center, thermal)
- Accessory unavailable

**The game never blocks, warns, or pauses because capture failed.** At most, the
round summary omits the clip section.

## 6. Data architecture

### 6.1 Source

`Multilingual_Vocabulary_1100.xlsx` — 1,100 rows, 9 categories:
Movie (200), TV Show (200), Celebrity, Animal, Food, Country, Sightseeing,
Superhero, Sport (100 each).

Columns: `Category`, `English`, `Cantonese (Spoken Traditional)`,
`Taiwan Chinese (Traditional)`, `Mainland Chinese (Traditional)`.

### 6.2 Known data issues to fix during ingestion

1. **The Mainland column is Traditional script in all 1,100 rows** — verified,
   zero Simplified-only characters. Convert it to Simplified at build time,
   preserving the curated regional vocabulary (盜夢空間 stays 盜夢空間, rendered
   Simplified). Use a standard Traditional→Simplified mapping; spot-check the
   200 Movie and 200 TV Show rows, where regional titles differ most.
2. **61% of rows have all three Chinese columns identical.** Expected — regional
   differences are real for proper nouns and nonexistent for common nouns (狗 is
   狗 everywhere). Not a bug. But it means the language picker should be framed
   as a regional preference, not four distinct word banks.
3. **100 words per category is thin.** A strong team burns 20–30 words in a
   120s round; four teams over three rounds will exhaust a single-category deck
   and reshuffle within one sitting. Mitigations: default Quick Play to all
   categories; warn in Custom Game when the selected deck is under ~150 words
   for the configured match length. Flag content expansion as the top v2 item.

### 6.3 Pipeline

A build-time Swift script converts the `.xlsx` to a bundled, validated JSON.
**The `.xlsx` is never read at runtime.**

Validation must fail the build on: missing localizations, duplicate English
entries, unknown categories, or any category falling below a minimum count.

### 6.4 Runtime model

Read-only content is **plain `Codable` structs decoded from bundled JSON into
memory**. Do not use SwiftData or Core Data for the word bank — 1,100 immutable
rows do not justify a persistent store or its migration surface.

```swift
struct GameWord: Codable, Identifiable, Sendable {
    let id: UUID
    let category: GameCategory
    let localizations: [ContentLanguage: String]
}

enum ContentLanguage: String, Codable, CaseIterable, Sendable {
    case english, cantonese, taiwanChinese, mainlandChinese
}
```

SwiftData is used **only** for user-owned state: match history, stats, custom
decks, settings. Keep that store small and separately versioned.

### 6.5 Localization

Two independent systems — do not conflate them:
- **UI chrome** → String Catalog (`.xcstrings`), follows system language.
- **Game content** → `ContentLanguage`, chosen in-app, persists across matches.

A player can run the UI in English and the words in Cantonese. That is a normal
case in Hong Kong, not an edge case.

---

## 7. Privacy and App Store compliance

### 7.1 Permissions

- `NSCameraUsageDescription`: explicit and honest — the app records the guessing
  team's reactions to play back at the end of the match, and video stays on the
  device.
- `NSMicrophoneUsageDescription`: the app records table audio so the reel has
  sound; audio stays on the device and is never uploaded or analysed.
- Photos write access requested **only** at the moment a player taps Save.

Camera and microphone are requested **together, once**, on the consent card
(§7.3) — never mid-round. Denying the microphone costs sound on the reel;
denying the camera costs the reel and the outer display (§5.3). Neither blocks
the game.

### 7.2 Audio/video handling — hard requirements

Recording with sound means capturing identifiable faces **and voices** of people
who never installed the app — and the audio picks up the whole table, including
people who are not on camera. Treat the rules below as non-negotiable.

1. All audio and video stays **on device**. No upload, no analytics, no speech
   recognition, no third-party SDK with any network access touching the capture
   pipeline.
2. Clips live in a dedicated temporary directory, excluded from backup.
3. **Unsaved clips are deleted when the match-end screen is dismissed.** Also
   purge on app launch — a crash must never leave footage of someone's friends
   on the device.
4. The rolling capture buffer is an intermediate. Discard it at round end, and
   delete any assembled clip once saved or once the match ends unsaved.
5. Privacy nutrition label: **no data collected.**

### 7.3 Consent

- A one-time card before the first match, stating plainly: **the guessing team is
  filmed and the table is recorded with sound**, everything stays on the device,
  and it can be turned off. This card requests camera and microphone together.
- A persistent recording indicator on the **outer display**, where the people
  being filmed are looking — plus a smaller one on the inner display, since the
  describer's voice is captured even though their picture is not.
- A **Reaction Camera** master toggle in settings. When off, the game plays
  normally and the outer display is simply unavailable — explain that tradeoff
  in the settings copy.
- An **audio-off** sub-toggle for groups who want the reel without voices. This
  drops the microphone permission entirely and still leaves the outer display
  working, since the accessory needs a video session, not audio.

### 7.4 Review notes to submit

State explicitly:

- The camera and microphone exist to produce the reaction reel — a recording of
  the guessing team that players watch and optionally save at match end. The
  outer display is a secondary benefit of `CameraCaptureAccessory`, not the
  reason for the capture session.
- Audio and video **never leave the device**: no upload, no analytics, no speech
  recognition. Unsaved footage is deleted when the match ends.
- Everyone recorded is shown a consent card before the first match, and a
  recording indicator appears on both displays throughout.
- The game is **fully playable without camera or microphone access on any
  iPhone**, including non-Duo hardware.

**Attach a demo video of Duo tabletop gameplay** — the reviewer probably does
not have the hardware, and the two-sided layout is the part that needs seeing.

### 7.5 Naming

The working title "Fun Duo Party Game" is a **placeholder and must not ship.**
"Duo" is an active Apple product name and using it in the app title is a
Guideline 5.2.1 risk. Ship a distinct brand name and put Duo in the *subtitle*
for discoverability ("Party charades for iPhone Duo"). Keep the bundle
identifier brand-neutral so renaming costs nothing.

---

## 8. Degradation matrix

| Condition | Behavior |
|---|---|
| Duo, tabletop, camera granted, accessory available | **Full experience.** Two-sided layout, outer scoreboard, reaction reel. |
| Duo, tabletop, accessory revoked mid-round | Outer content stops. Round continues uninterrupted. Reel may be truncated. No user-facing error. |
| Duo, tabletop, camera denied | Two-sided inner layout works. No outer display, no reel. Settings explains why. |
| Duo, tabletop, mic denied or audio off | Capture continues, reel is silent. No other change. |
| Duo, flat / fully open | Single-screen layout on the inner display. Fully playable. |
| Duo, folded shut mid-match | Pause. Resume affordance on reopen. |
| Non-Duo iPhone | **Full single-screen pass-the-phone game.** Word, timer, two hit zones. No camera, no fold, no outer display. Complete and satisfying on its own. |

The non-Duo path is not a courtesy — it is how the app survives App Review
(§1.2.4) and how it satisfies Apple's fully-functional-without-accessory
requirement (§1.2.3). It gets real design attention, not a stub.

---

## 9. Monetization foundation (v1 ships free)

No IAP in v1, but do not paint into a corner:

- Model content as **packs** from day one. The 9 built-in categories are a pack
  with `price: .free`. Adding a paid pack later is data, not refactoring.
- Route every content-availability check through a single
  `ContentEntitlementStore` protocol. v1 ships an `AlwaysUnlocked` implementation.
- Keep a stable `packID` in the bundled JSON schema.
- Do **not** add StoreKit, a paywall, a receipt validator, or an account system
  in v1. The abstraction is the whole investment.

---

## 10. Technical architecture

### 10.1 Concurrency and lifecycle

- Swift 6 language mode, strict concurrency.
- `GameEngine` is a `@MainActor @Observable` final class, the single source of
  truth, shared by both scenes.
- Scene-based lifecycle is mandatory on this SDK — an app without `UIScene`
  support will not launch.

### 10.2 Scenes

Two scenes over one model:
1. **Main scene** — inner display, all interaction.
2. **Accessory scene** — `CameraCaptureAccessory` content, read-only projection
   of `GameEngine`. It must not own state or mutate the model.

### 10.3 Timer

Wall-clock deltas from a monotonic source (`ContinuousClock`), never accumulated
`Timer` ticks. Persist the round's start instant and duration, not a remaining
count, so backgrounding and interruption resolve correctly on return.
Set `isIdleTimerDisabled = true` for the duration of a round only.

### 10.4 Feedback

- Correct: `UIImpactFeedbackGenerator(style: .heavy)` + ascending chime.
- Skip: `UINotificationFeedbackGenerator(type: .error)` + low buzz.
- Final 10s: a tick per second, escalating.
- `AVAudioSession`: `.ambient` with `mixWithOthers` when not recording. During a
  round with audio capture the category must become `.playAndRecord` with
  `mixWithOthers` **and** `defaultToSpeaker` — the party's music must keep
  playing from other apps. Return to `.ambient` the moment the round ends; never
  hold a recording category across the summary screen.
- Expect the microphone to pick up that background music. This is acceptable for
  a party reel and must not be treated as a bug — do not add noise suppression
  or ducking, which would flatten the laughter along with the music.
- Respect the silent switch. Haptics must carry the full interaction on their
  own, because they will be the only feedback much of the time.

### 10.5 Module layout

```
DuoParty/
├── Core/          GameEngine, MatchState, Scoring, Deck, RoundTimer
├── Content/       GameWord, GameCategory, ContentLanguage, ContentStore,
│                  ContentEntitlementStore
├── Capture/       CameraDirectionResolver, ReactionRecorder, HighlightExtractor,
│                  ReelExporter (concatenation + 1×/2×/3× speed)
├── Posture/       HingeObserver, PostureState, FoldGeometry
├── Scenes/
│   ├── Main/      SetupFlow, DescriberView, TabletopLayout, SingleScreenLayout,
│   │              RoundSummary, MatchEnd
│   └── Accessory/ GuesserScoreboard
├── Design/        Theme, Typography, Motion, Haptics, SoundBank
└── Tools/         xlsx-to-json build plugin + validator
```

### 10.6 Testing

- Unit: scoring (incl. skip penalty), deck exhaustion and reshuffle, timer
  correctness across background/foreground, highlight window extraction,
  capture-state resolution under each permission combination, gradient colour at
  arbitrary elapsed fractions.
- The Duo simulator in Xcode 27.1 Device Hub covers fold, rotate, and partial
  postures. **It cannot simulate the camera accessory or capture** — those need
  hardware. Plan a hardware validation pass before submission.
- Capture states (§5.3) must be forceable by a debug setting so Silent and None
  can be exercised on any device without revoking real permissions.
- Snapshot tests for tabletop, flat, and non-Duo layouts.

---

## 11. Design direction

One theme in v1, executed properly. The other three from the draft are cut.

- **Native Liquid Glass.** Use the system material and glass APIs; do not
  hand-roll the effect.
- Typography is the product. The word on the lid is the single most important
  element in the app — size it to fill the surface, and handle CJK line height
  and Latin descenders without clipping. Test 陳奕迅 and "The Shawshank
  Redemption" in the same layout.
- Motion: purposeful and fast. Word transitions, score increments, final-10s
  urgency. Nothing decorative that delays a tap.
- Dark by default. This gets played in dim rooms.

### 11.1 Accessibility

- Dynamic Type throughout the UI. The word display scales beyond standard sizes
  by design, but must never clip or truncate.
- Hit zones ≥ 44pt, and in practice far larger.
- VoiceOver on all setup and summary screens. Gameplay is inherently visual, but
  scores and round results must be readable.
- Respect Reduce Motion and Reduce Transparency.
- Colour is never the only channel — Correct/Skip differ by position, haptic,
  sound, and icon, not just green/red.

---

## 12. Milestones

| # | Milestone | Exit criteria |
|---|---|---|
| M1 | Content pipeline | ✅ xlsx→JSON with Simplified conversion, validator failing the build on bad data, decoded and queryable |
| M2 | Core engine | ✅ Deck, scoring, timer, match structure — fully unit tested, no UI |
| M3 | Single-screen game | ✅ Complete playable game on any iPhone. **Shippable on its own.** |
| M4 | Tabletop layout | ✅ Hinge detection, crease-aware split, 180°-rotated far edge, blind-tap zones |
| M5 | Outer display | Accessory scene, scoreboard, availability handling incl. mid-round revocation |
| M6 | Reaction camera | Direction resolution, capture with audio, state handling (§5.3), highlight extraction, playback, 1×/2×/3× export, save/auto-delete |
| M7 | Polish & a11y | Theme, motion, haptics, Dynamic Type, VoiceOver |
| M8 | Submission | Hardware validation, review notes, demo video, final name |

M3 is the critical gate: if the single-screen game is not fun on its own, the
two-sided version will not save it.

---

## 13. Open items

1. **Final app name** — blocking submission, not development (§7.5).
2. **Thermal validation** — camera + microphone + dual display + ProMotion
   across repeated 120s rounds. If it throttles: drop to 540p, then shorten the
   rolling buffer, then disable capture. Validate on a hot device at the end of
   a full 4-team match, not a cold one on round one. Materially lower risk now
   that only one camera runs, but still unverified without hardware.
3. **Hardware access** — nothing in M6 is truly verified until tested on a real
   Duo. Budget for a device before submission.
4. **Content depth** — 100 words/category is the known weak point (§6.2.3).
5. **Simplified conversion quality** — the automated pass needs a native reader
   to spot-check the 400 Movie/TV rows.

## 14. Explicitly out of scope for v1

Target Mode · themes beyond the one · interactive outer display · online/remote
play · accounts · Game Center · iPad or Mac · custom word lists · IAP · sharing
beyond a local Photos save · speech recognition or any on-device analysis of
captured audio · describer-facing capture · multi-camera sessions.
