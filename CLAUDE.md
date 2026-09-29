# Project: CharaDUO

> **Name history:** working title "Fun Duo Party Game" → code name
> `PartyCharades` (M1–M7) → final name **CharaDUO** (2026-09-23; always Latin
> script, every language). Only user-visible surfaces carry the new name. The
> Xcode project/target/module and bundle ID `com.ryopang.partycharades` stay
> `PartyCharades` **deliberately** — do not rename them. The "Duo" trademark
> risk (Guideline 5.2.1, §7) is accepted by the owner; note it in M8 review notes.

Native iOS charades party game for iPhone Duo's tabletop posture.
**Full spec: [`PRD v1 - Fun Duo Party Game.md`](./PRD%20v1%20-%20Fun%20Duo%20Party%20Game.md)** — read the
relevant section before implementing. This file is the working contract; the PRD
is the detail.

iOS 27.1+ · Xcode 27.1 · SwiftUI · Swift 6 strict concurrency

### Source of truth

| File | Status |
|---|---|
| `PRD v1 - Fun Duo Party Game.md` | **Authoritative.** |
| `CLAUDE.md` | **Authoritative.** Working contract. |
| `DUO PRD Draft` | ⛔️ **Superseded — do not read or follow.** |
| `DUO.md` | ⛔️ **Superseded — duplicate of the draft above.** |

The two superseded files contain decisions that were investigated and
**rejected**: gyroscope-based posture detection, auto-pause on posture change,
SwiftData for the word bank, four visual themes, Target Mode, and an outer
display treated as a guaranteed core mechanic. If you find yourself implementing
any of those, you are reading the wrong file.

---

## 0. Start of every session — do this first

**Before writing any code, state these three things:**

1. **Which milestone** you are working on (see §5).
2. **Which model you are running as** (Opus 5.5 / Sonnet 5 / Haiku 4.5 / other).
3. **Whether that model matches the recommendation below.** If it does not, say
   so plainly and ask whether to switch before starting. Do not silently proceed
   on a mismatch — switching costs one minute now and hours later.

### Model per milestone

| Milestone | Model | Why |
|---|---|---|
| M1 content pipeline | **Sonnet 5** | Mechanical and fully specified — xlsx parse, T→S conversion, validation |
| M2 core engine | **Sonnet 5** | Pure logic with clear unit tests; the spec already says what to build |
| M3 single-screen game | **Sonnet 5** | Conventional SwiftUI, well-trodden |
| **M4 tabletop layout** | **Opus 5.5** | Crease-aware geometry, novel APIs, 180° rotation — reasoning from headers rather than memory |
| **M5 outer display** | **Opus 5.5** | Two scenes over one model, revocable availability, subtle lifecycle bugs |
| **M6 reaction camera** | **Opus 5.5** | AVFoundation is fiddly even when you know it; here it's capture + buffering + export |
| M7 polish & a11y | **Sonnet 5** | Design iteration; fast turnaround matters more than depth |
| M8 submission | **Sonnet 5** | Mostly metadata, notes, and checklists |

**Rules:**
- **Use plan mode before M4, M5 and M6.** Read the headers, propose an approach,
  get agreement — *then* write code. On APIs nobody has memorized, a wrong
  architectural assumption is expensive to unwind.
- **Do not switch models mid-milestone.** Finish the slice, commit, then switch.
- The model is changed from the app's model picker, not a slash command.

---

## 1. The hard rule: never trust training data for iPhone Duo APIs

**iPhone Duo shipped in September 2026, after every current model's training
cutoff.** No model knows `onHingeChange`, `reservedRegions`,
`CameraCaptureAccessory` or `UISceneAccessory` from training. Asked cold, every
model produces confident, fluent, wrong code — plausible API names that do not
exist.

**Therefore: verify every Duo, fold, scene-accessory or capture symbol against
the installed SDK before using it.** Not against documentation, not against blog
posts, not against memory.

```bash
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
# UIKit / AVFoundation / AVKit — plain headers
grep -rn "SymbolName" "$SDK/System/Library/Frameworks/UIKit.framework/Headers/"
```

```bash
# SwiftUI — note the gotcha below
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
grep -n "onHingeChange" "$SDK/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface"
```

> **Gotcha:** `onHingeChange` and `reservedRegions` live in **SwiftUICore**, not
> SwiftUI. Grepping SwiftUI's own `.swiftinterface` returns nothing and will
> convince you they don't exist. They do — SwiftUI re-exports them.

If a symbol is not in the SDK, **stop and say so.** Do not invent a plausible
alternative, and do not fall back to a pre-Duo API that "looks close."

---

## 2. Verified API surface

Every entry below was confirmed in the iOS 27.1 SDK headers. **Do not design
around anything not on this list without verifying it first.**

| API | Module | Purpose |
|---|---|---|
| `onHingeChange(isEnabled:_:)` → `DeviceHingeContext` | SwiftUICore | Posture and hinge angle |
| `GeometryProxy.reservedRegions(kind:options:)` | SwiftUICore | Locate the fold crease |
| `.sceneAccessory { CameraCaptureAccessory(...) }` | SwiftUI | Outer-display content |
| `.onAvailabilityChange { }` | SwiftUI | System granting/revoking the outer display |
| `UISceneAccessory.cameraCapture(sceneConfiguration:)` | UIKit | UIKit equivalent |
| `UISceneAccessoryRegistration.isAvailable` (read-only) / `.isEnabled` (read-write) | UIKit | System owns availability; we own only whether we draw |
| `UIHingeInteraction` · `UIHinge` · `UIHingeStatus` | UIKit | UIKit hinge (not needed — SwiftUI path is complete) |
| `ArrangementView` / `UIArrangementViewController` | SwiftUI / UIKit | Adaptive two-pane (setup screens only, not gameplay) |
| `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)` | AVKit | Which cameras face a given view, live as the device folds |
| `AVCaptureDeviceDirectionMap.forwardFacingDeviceDescriptors` | AVKit | The cameras pointing at the guessers |
| `AVCaptureDeviceTypeBuiltInOuterUltraWideCamera` / `...InnerUltraWideCamera` | AVFoundation | Duo camera clusters |
| `AVCaptureDevice.systemPressureState.level` | AVFoundation | Thermal monitoring during long rounds. ⚠️ `systemPressureCost` is **`AVCaptureMultiCamSession`-only** (AVCaptureSession.h:847) — not on the single-camera `AVCaptureSession` used here |
| `AVCaptureSession.synchronizationClock` | AVFoundation | Stamps Correct taps on the same clock as the recorded frames |
| `AVMutableComposition.scaleTimeRange(_:toDuration:)` | AVFoundation | 2×/3× export |
| `AVAudioTimePitchAlgorithmVarispeed` | AVFoundation | Speed-up with pitch shift (intentional — see §4) |

---

## 3. Four constraints that shape everything

1. **There is no general API to draw on the outer display.** No second
   `UIScreen`, no arbitrary secondary window. The only route is a scene accessory.
2. **The only Duo scene accessory is `cameraCapture`** — it requires the app
   foregrounded, full-screen on the inner display, and an **active
   `AVCaptureSession`**. No camera session means no outer display.
3. **Accessory availability is system-controlled and revocable at any moment.**
   From `UISceneAccessory.h`: *"the app must remain fully functional without
   them."* The outer display is an enhancement layer. Nothing in game state may
   depend on it, and it must be able to vanish mid-round without interrupting play.
4. **There is no Duo device-capability key.** The app cannot be restricted to
   iPhone Duo. Assume App Review tests on a non-Duo iPhone — the single-screen
   game is load-bearing, not a courtesy.

---

## 4. Conventions — decided, do not relitigate

**Data**
- Word bank is **bundled JSON decoded into memory**. Not SwiftData, not Core Data.
  1,100 immutable rows do not justify a persistent store or its migration surface.
- Source sheet is `Multilingual_Vocabulary.xlsx`; run `Scripts/regenerate-content.sh`
  after editing it. Columns are found by header. Optional `Region` column
  (HK/TW/CN/JP, blank = global) drives the 70/30 deck weighting in `Deck`.
- **Adding a language:** a `ContentLanguage` case (+ `homeRegion`, `sourceColumnHeader`,
  `catalogCode`, `locale`, names in `DisplayNames.swift`), a sheet column, a
  `knownRegions`/`CFBundleLocalizations` entry in `project.yml`, and a column in
  the xcstrings catalogs (`Scripts/l10n/xcstrings_xlsx.py` LANGS). The compiler
  flags every exhaustive switch you missed.
- SwiftData is for **user state only**: stats, settings, custom decks.
- The `.xlsx` is a build-time input. **Never read it at runtime.**
- The source spreadsheet's "Mainland Chinese" column is **Traditional script** —
  convert to Simplified during ingestion (PRD §6.2).

**Timing**
- Round timer uses **wall-clock deltas from `ContinuousClock`**. Never accumulated
  `Timer` ticks. Persist the start instant and duration, never a remaining count.
- `isIdleTimerDisabled = true` during a round only.

**Concurrency**
- Swift 6 strict concurrency. `GameEngine` is `@MainActor @Observable`, the single
  source of truth, shared by both scenes.
- The accessory scene is a **read-only projection**. It must not own or mutate state.

**Capture**
- **Guessers only, with audio.** The describer is deliberately not filmed — the
  inner camera can't frame them usefully in tabletop posture. Audio already
  carries their performance. Do not add a second camera feed.
- The capture session (what makes the outer display available at all — it
  requires an active `AVCaptureSession`) spans a whole match, not just each
  timed round: it starts at match begin and stays running through round
  summary and Game Over, so the outer display can mirror those screens too.
  It only tears down when the player actually leaves the match (home, a new
  custom game, rematch) or pauses.
- **Recording** is narrower than the session: only during a live, unpaused
  round, only after the direction coordinator in the accessory scene has
  named the camera facing the guessers, and never after thermal pressure
  hits `.critical`. The mic input and `.playAndRecord` are attached per round
  and removed at round end. The session only starts on Duo hardware
  (detected via the outer ultra-wide device type), so non-Duo iPhones never
  light the camera indicator.
- The rolling buffer is rotating ~2s `AVAssetWriter` segment files, pruned
  live; at round end only segments under highlight windows survive. All
  footage lives in `tmp/ReactionReel`, purged on launch and whenever the
  match is left.
- **Swift 6 trap:** a closure written inside a `@MainActor` type that
  AVFoundation/Photos calls on its own queue (KVO handlers, `performChanges`)
  is inferred main-actor isolated and **traps at runtime**. Build such
  closures in `nonisolated` functions. This already crashed once (Photos
  save); the capture KVO paths only run on hardware.
- Export is **deferred to Save**, never live. Speed is a render parameter.
- Varispeed pitch shift at 2×/3× is **intentional**. Chipmunked audio is the joke.
  Do not "fix" it with pitch correction.

**Design**
- Countdown is **descending digits** with a **green → amber → red** background ramp.
  Never green→red directly — that's the one palette red-green colour deficiency
  can't read. Digits are the primary channel; colour is never the only cue.
- The countdown colour is **one flat colour filling the whole area**, migrating
  green → amber → red (no bottom-up wipe). Applies to the single-screen top half,
  the outer display **and the entire describer lid** (changed
  2026-09-23) — keep the word legible on the lid with a high-contrast card.

**Failure handling**
- Capture, accessory availability and posture changes all degrade **silently**.
  Never block, warn, or pause gameplay because one of them failed.
- The only posture event that pauses a match is `.closed`.

---

## 5. Milestones

Update the status marks as work lands.

- [x] **M1** Content pipeline — xlsx→JSON, T→S conversion, build-failing validator
- [x] **M2** Core engine — deck, scoring, timer, match structure; unit tested, no UI
- [x] **M3** Single-screen game — **complete and shippable on any iPhone**
- [x] **M4** Tabletop layout — hinge detection, crease-aware split, blind-tap zones
  *(the 180° guesser far edge was removed 2026-09-23: the inner display is describer-only)*
- [x] **M5** Outer display — accessory scene, mid-round revocation handling
- [x] **M6** Reaction camera — capture + audio, highlights, 1×/2×/3× export, auto-delete
  *(simulator-verified via `-uiTestSyntheticCamera`; direction resolution, camera swap on hinge move and thermal step-down need a real Duo — M8)*
- [x] **M7** Polish & accessibility
- [ ] **M8** Submission — hardware validation, review notes, demo video, final name

**M3 is the critical gate.** If the single-screen game isn't fun on its own, the
two-sided version will not save it. Do not start M4 until M3 stands alone.

---

## 6. Testing

- The Xcode 27.1 Device Hub Duo simulator covers fold, rotate and partial postures.
  **It cannot simulate the camera accessory or capture** — those need hardware.
- Capture states (Full / Silent / None) and accessory availability must be
  **forceable by a debug setting**, so every path is exercisable without real
  permission revocation or real hardware failure.
  `-uiTestCaptureState full|silent|none` forces the state;
  `-uiTestSyntheticCamera` feeds generated frames + tone through the real
  recorder so the whole reel path runs on the simulator.
- Package tests: `swift test --package-path Packages/X --scratch-path "$TMPDIR/sb-X"`.
  The scratch path matters — building inside `~/Documents` fails codesign on
  iCloud file attributes ("resource fork … not allowed").
- Unit-test: scoring incl. skip penalty, deck exhaustion and reshuffle, timer
  correctness across background/foreground, highlight window extraction, gradient
  colour at arbitrary elapsed fractions.

---

## 7. Known traps

- Hinge APIs are in **SwiftUICore**, not SwiftUI (§1).
- The outer display needs a **video** session, not audio — denying the microphone
  costs sound on the reel and nothing else.
- Duo uses **Touch ID**, not Face ID. Don't hardcode biometric assumptions.
- The inner display reports **regular** width *and* height size classes — unusual
  for iPhone, and it will break layout assumptions copied from other projects.
- Never hardcode the fold position or a 50/50 split. Read `reservedRegions`.
- Never hardcode which camera faces the guessers. Use the direction coordinator.
- The app title must not ship containing "Duo" (Apple trademark, Guideline 5.2.1).
  Keep the bundle identifier brand-neutral so renaming is free.
