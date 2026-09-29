# CharaDUO

A native iOS charades party game built for iPhone Duo's tabletop posture. The
whole inner display belongs to the describer: the word on the upright half,
Correct and Skip on the half lying on the table. The guessers only ever see
the outer display: category, countdown, a row of emoji showing how long the
answer is, and the score. A reaction camera records their guesses into a
highlight reel played back at the end of the match.

The app is fully playable single-screen on any iPhone — the tabletop and
outer-display features are an enhancement layer, never a requirement.

**Full spec:** [`PRD v1 - Fun Duo Party Game.md`](./PRD%20v1%20-%20Fun%20Duo%20Party%20Game.md)
**Working contract:** [`CLAUDE.md`](./CLAUDE.md)

> **Name:** the app ships as **CharaDUO** (chosen 2026-09-23). The Xcode
> project, target, module and bundle ID `com.ryopang.partycharades` keep the
> old `PartyCharades` code name on purpose — brand-neutral identifiers make
> any future rename a display-name change only. The "Duo" trademark risk
> (Guideline 5.2.1) is a known, accepted risk.

## Status

`v1.2.3` (build 6). M1–M7 are complete, M8 is in progress. **Still needs a real
iPhone Duo** for the hardware pass and the demo video; the checklist is in
[`Submission/HARDWARE-VALIDATION.md`](./Submission/HARDWARE-VALIDATION.md).

### 1.2.3 (2026-09-23)

- **Outer display language:** the outer display now follows the in-app language
  instead of the system language (e.g. Taiwan no longer shows Cantonese text).


### 1.2.2 (2026-09-23)

- **Category emoji:** Food is now 🍽️ and Sightseeing is 📸.

### 1.2.1 (2026-09-23)

- **Outer display emoji count fix.** Emoji now count only the answer itself:
  a parenthetical original ("湯姆克魯斯 (Tom Cruise)" → 5) and the English half
  of a bilingual brand ("Nike / 耐吉" → 2) are no longer counted.

### 1.3.1 (2026-09-28)

- **Custom Correct / Skip sounds** replace the system placeholders. Sources:
  `Sound files/*.mp3`; the app bundles `App/Resources/Sounds/*.caf`
  (`afconvert "Sound files/x.mp3" App/Resources/Sounds/x.caf -f caff -d LEI16`).

### 1.3.0 (2026-09-28)

- **Japanese.** New UI language (`ja`, polite です/ます) and a fifth word
  language. Vocabulary grows to **1,394 words** (194 Japan-focused additions).
  The word-language picker, Settings, Info.plist prompts and the outer display
  all follow it; a Japanese phone starts in Japanese.
- **Regional 70/30 deck.** Words can carry a `Region` tag (HK, TW, CN, JP). In
  a match, the language's home region (Cantonese → HK, Taiwan → TW, Mainland →
  CN, Japanese → JP) supplies ~70% of draws and everything else ~30%. English
  and untagged mixes are unweighted. See `Deck` in `Packages/Core`.
- **Content pipeline:** the spreadsheet is now `Multilingual_Vocabulary.xlsx`
  (no count in the name). Columns are read by header, so adding a language is
  one `ContentLanguage` case, one `sourceColumnHeader`, one sheet column.
  Fixed a parser bug where an empty cell inherited the previous cell's text.

### 1.2.0 (2026-09-23) (2026-09-23)

- **New category: Brand.** 100 words (Apple, …) in all four word languages,
  bringing the built-in set to **10 categories and 1,200 words**. Named 品牌 in
  the Chinese UI languages, with a 🏷️ emoji.

### 1.1.0 (2026-09-23)

- **Outer display redesign.** Top to bottom: category name, countdown, one
  category emoji per letter or CJK character of the answer ("Avengers" → 8 🦸,
  "蛋撻" → 2 🍽️) with gaps between words, then a team/score pill. The emoji row
  is the biggest element and shrinks to fit long titles. Only the answer's
  shape reaches the outer display, never the word.
- **Outer display turns a quarter turn clockwise in tabletop**, so it reads
  upright to the guessers. It is centred on the whole panel, with REC in the
  top-right corner, clear of the camera.
- **Tabletop detection widened to 70–150°** (was 75–115°). The Duo simulator's
  tabletop pose reports 127.8°, which the old range treated as flat.
- **No more guesser strip on the inner display.** The 180° far edge is gone;
  Correct and Skip fill the whole table half.
- **Correct/Skip redesign:** gradient Correct card (violet → magenta, so it
  can't be confused with the countdown green) and a dark-glass Skip card.
- **Language:** the app follows the phone's language until one is picked in
  Settings, and only that choice is saved. Custom Game has a per-match
  **Word Language** picker that never changes the UI.
- **Custom Game:** a 180s round length (30/60/90/120/180s); the skip-penalty
  option reads just "Yes".
- **Versioning fix:** `Info.plist` now reads `MARKETING_VERSION` /
  `CURRENT_PROJECT_VERSION`; it had hard-coded 1.0 (1).

### Earlier

- **1.0.0:** design refresh (icon, launch screen, always-dark purple theme, SF
  Rounded, full-area countdown colour, tick sound, four-language UI:
  English, Hong Kong Cantonese, Taiwan and Mainland Chinese), plus M8 docs:
  privacy manifest, export-compliance key, review notes, App Store metadata
  draft and demo shot list in [`Submission/`](./Submission).
- **Playtest polish:** larger word/countdown text, fully tappable Correct/Skip
  zones, and a countdown-freeze fix (the engine didn't mutate between ticks,
  so SwiftUI could skip re-rendering the digit; "now" is now threaded down
  explicitly).

UI translations are QA'd through `CharaDUO-UI-strings.xlsx`; re-import with
`Scripts/l10n/xcstrings_xlsx.py import`.

| # | Milestone | Status |
|---|---|---|
| M1 | Content pipeline (xlsx→JSON, Simplified conversion, validator) | ✅ |
| M2 | Core engine (deck, scoring, timer, match structure) | ✅ |
| M3 | Single-screen game — complete and shippable on any iPhone | ✅ |
| M4 | Tabletop layout (hinge detection, crease-aware split, blind-tap zones) | ✅ Guesser far edge removed in 1.1.0 |
| M5 | Outer display (accessory scene, scoreboard, availability handling) | ✅ Redesigned + tabletop quarter turn in 1.1.0 |
| M6 | Reaction camera (capture + audio, highlights, export, auto-delete) | ✅ Simulator-verified; hardware pass in M8 |
| M7 | Polish & accessibility | ✅ |
| M8 | Submission (hardware validation, review notes, demo video) | 🟨 Docs + manifests done; hardware pass and video pending |

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

`Multilingual_Vocabulary.xlsx` is a build-time-only input — the app
never reads it at runtime. To regenerate the bundled JSON after editing the
spreadsheet:

```bash
./Scripts/regenerate-content.sh
```

### Running tests

Each module under `Packages/` is an independent Swift package:

```bash
swift test --package-path Packages/Core --scratch-path "$TMPDIR/sb-Core"
```

Same for `Content`, `ContentPipeline`, `Posture`, `Capture` and `Design`. The
`--scratch-path` matters: building inside `~/Documents` fails codesign on
iCloud file attributes.

UI tests (`App/UITests`) run via `xcodebuild test` against a booted iPhone
Duo simulator and exercise the real rendered app end to end: Quick Play,
Custom Game, the tabletop layout, language settings, the capture consent flow
and the reaction reel. **Unfold the simulator first.** If it boots folded
shut, the app runs on the outer screen and the reel tests fail.

Useful debug launch arguments: `-uiTestAutoStart`, `-uiTestSkipConsent`,
`-uiTestSyntheticCamera`, `-uiTestCaptureState full|silent|none`,
`-uiTestPosture tabletop|flat|closed|noHinge`,
`-uiTestContentLanguage english|cantonese|taiwanChinese|mainlandChinese`,
`-uiTestResetAppLanguage`.

### Checking the outer display in the simulator

Look at the Device Hub simulator window. Raw `simctl io screenshot` captures
of the outer panel come out turned 180° and offset, so don't judge
orientation or centring from them.

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

- **M6 (reaction camera) is verified on the simulator only**, through
  `-uiTestSyntheticCamera` (generated frames + tone through the production
  recorder, composer and exporter). Still needs a real Duo:
  `AVCaptureDeviceDirectionCoordinator` resolution in the accessory scene,
  the input swap when the hinge moves, horizon-level rotation of the
  footage, and thermal step-down over a full 4-team match.
- **Sound effects are placeholders.** Correct/Skip/countdown-tick haptics are
  fully implemented per spec; the accompanying chimes use built-in system
  sound IDs standing in for real designed audio assets.
- **Outer display orientation and camera position** are confirmed in the
  simulator window only. On a real Duo, check the text reads upright in
  tabletop (`QuarterTurn.angle` is the one place to change it) and that REC
  and the text clear the camera. The simulator's safe-area insets don't match
  where it draws the camera.
- **Tabletop angle range (70–150°)** is tuned to the simulator. Note the real
  hinge angle when the phone is propped on a table.
- Several Duo-specific paths (a real fold event through `onHingeChange`, the
  outer display actually being presented, real mid-round accessory
  revocation) have only been verified via DEBUG-only overrides on the iPhone
  Duo simulator — the simulator can't run a capture session, so the outer
  display itself has never been seen on real hardware.
