# Party Charades *(working title)*

A native iOS charades party game built for iPhone Duo's tabletop posture. The
describer reads a word on the vertical inner half; the guessers watch a
scoreboard on the outer display, while a reaction camera records their
guesses into a highlight reel played back at the end of the match.

The app is fully playable single-screen on any iPhone — the tabletop and
outer-display features are an enhancement layer, never a requirement.

**Full spec:** [`PRD v1 - Fun Duo Party Game.md`](./PRD%20v1%20-%20Fun%20Duo%20Party%20Game.md)
**Working contract:** [`CLAUDE.md`](./CLAUDE.md)

> "Party Charades" and the `com.ryopang.partycharades` bundle ID are
> placeholders — see PRD §7.5. Final naming is an open item before App Store
> submission.

## Status

`v0.1.0` — 6 of 8 milestones complete. Not yet submitted; no hardware
validation has been done (see M6/M8 below).

Since the initial M7 pass, a second playtest-driven polish round tightened
layout across the launch screen, Custom Game setup, in-round gameplay, and
the results screens (larger word/countdown text, fully tappable Correct/Skip
zones, results anchored to the bottom of their screen), and fixed a
countdown-freeze bug: the timer's `@Observable` engine wasn't mutating its
own properties between ticks, so SwiftUI's fine-grained diffing could skip
re-rendering the digit even while `TimelineView` kept firing. The fix threads
"now" down explicitly rather than relying on implicit observation.

| # | Milestone | Status |
|---|---|---|
| M1 | Content pipeline (xlsx→JSON, Simplified conversion, validator) | ✅ |
| M2 | Core engine (deck, scoring, timer, match structure) | ✅ |
| M3 | Single-screen game — complete and shippable on any iPhone | ✅ |
| M4 | Tabletop layout (hinge detection, crease-aware split, 180° far edge) | ✅ |
| M5 | Outer display (accessory scene, scoreboard, availability handling) | ✅ |
| M6 | Reaction camera (capture + audio, highlights, export, auto-delete) | ⬜ Needs real Duo hardware |
| M7 | Polish & accessibility | ✅ |
| M8 | Submission (hardware validation, review notes, demo video, final name) | ⬜ Blocked on M6 |

## Requirements

- Xcode 27.1, iOS 27.1 SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`
  from `project.yml` (fetched automatically by the script below if not
  already installed)

## Getting started

```bash
./Scripts/generate-xcodeproj.sh
open PartyCharades.xcodeproj
```

Build and run the `PartyCharades` scheme on any iOS 27.1+ simulator or
device. The tabletop/outer-display paths need an iPhone Duo simulator
(Xcode's Device Hub can create one) or hardware; everything else runs on a
regular iPhone.

### Regenerating the word bank

`Multilingual_Vocabulary_1100.xlsx` is a build-time-only input — the app
never reads it at runtime. To regenerate the bundled JSON after editing the
spreadsheet:

```bash
./Scripts/regenerate-content.sh
```

### Running tests

Each module under `Packages/` is an independent Swift package:

```bash
swift test --package-path Packages/Content
swift test --package-path Packages/ContentPipeline
swift test --package-path Packages/Core
swift test --package-path Packages/Posture
swift test --package-path Packages/Capture
swift test --package-path Packages/Design
```

UI tests (`App/UITests`) run via `xcodebuild test` against a booted
simulator and exercise the real rendered app end to end — Quick Play,
Custom Game, the tabletop layout, and the capture consent flow.

## Architecture

```
Packages/
├── Content/          Word bank model + bundled JSON store (no SwiftData)
├── ContentPipeline/   Build-time xlsx→JSON tool: parsing, T→S conversion, validation
├── Core/              GameEngine, deck, scoring, timer, match state — pure logic
├── Posture/           Hinge/fold posture resolution + crease geometry
├── Capture/           Capture session state, permissions, audio session policy
└── Design/            Countdown colour ramp + haptic/sound event mapping

App/
├── Sources/PartyCharades/   SwiftUI app: setup, gameplay, round summary, match end
└── UITests/                 XCUITest suite driving the real app
```

Business logic lives in testable Swift packages; the App target is a thin
SwiftUI layer over them. See `CLAUDE.md` for the conventions this project
holds itself to (timing, concurrency, data, and design decisions that are
settled and shouldn't be relitigated).

## Known gaps

- **M6 (reaction camera)** is unbuilt. The outer display currently runs a
  video-only capture session (just enough to make `CameraCaptureAccessory`
  available, now kept alive for the whole match — including round summary
  and Game Over — rather than just each timed round); there is no rolling
  buffer, highlight extraction, or export yet. "Save Video" on the Game Over
  screen is a visible but disabled stub until M6 lands.
- **Sound effects are placeholders.** Correct/Skip/countdown-tick haptics are
  fully implemented per spec; the accompanying chimes use built-in system
  sound IDs standing in for real designed audio assets.
- **Final app name is undecided** (PRD §7.5).
- Several Duo-specific paths (a real fold event through `onHingeChange`, the
  outer display actually being presented, real mid-round accessory
  revocation) have only been verified via DEBUG-only overrides on the iPhone
  Duo simulator — the simulator can't run a capture session, so the outer
  display itself has never been seen on real hardware.
