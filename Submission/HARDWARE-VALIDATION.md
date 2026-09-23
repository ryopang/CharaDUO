# Hardware validation checklist (needs a real iPhone Duo)

Nothing in M6 is verified until this is done (PRD §13.2–3). Tick each item on
device; record failures with a screen recording. Build Release for the device
first; also run a Debug build with `-uiTestCaptureState none|silent|full` to
exercise degraded paths.

## Posture & layout (M4)
- [ ] Tabletop: split follows the real crease (`reservedRegions`); no hardcoded 50/50.
- [ ] Far edge reads upright from the guessers' side; blind-tap zones reachable while standing.
- [ ] Fold to `.closed` mid-round pauses the match; reopening resumes.
- [ ] Flat / partial postures fall back to single-screen without losing the round.

## Outer display (M5)
- [ ] Scoreboard appears when the capture session runs; countdown colour matches inner.
- [ ] Revoke mid-round (e.g. leave full-screen / system takes it): round continues, no error UI.
- [ ] Availability returns → outer content resumes.
- [ ] REC indicator visible on the outer display while recording.
- [ ] **Tabletop:** outer-display text reads upright to the guessers (rotated a quarter turn
      clockwise). If it's sideways the other way or upside-down, change `QuarterTurn.angle`
      in `OuterDisplayModifier.swift`. Upright in the Device Hub simulator window (2026-09-23);
      `simctl` framebuffer captures of that panel come out 180° turned and offset, so ignore those.
- [ ] Tabletop detection: note the real hinge angle when propped on a table; the band is 70–150°
      (`PostureResolver.tabletopAngleRange`). The simulator's tabletop pose reports 127.8°.
- [ ] Flat: outer display unrotated, content clear of the camera cluster (82 pt top inset in the sim).
- [ ] Emoji row: one category emoji per letter/character, gaps between words, fits long titles.

## Capture (M6)
- [ ] Direction coordinator names the camera facing the guessers; recording starts only then.
- [ ] Camera swap when the hinge moves mid-round.
- [ ] Audio captured; denying mic still yields video reel + outer display.
- [ ] Denying camera: game works, no outer display, no reel, Settings explains.
- [ ] Highlights cut correctly around Correct taps (`synchronizationClock` alignment).
- [ ] 1×/2×/3× export plays; pitch shift at 2×/3× is intentional.
- [ ] Save to Photos permission asked only at Save; unsaved footage gone after leaving match; `tmp/ReactionReel` purged on relaunch (kill app mid-round to test).

## Thermal (PRD §13.2)
- [ ] Hot device, end of a full 4-team match, 120 s rounds: watch `systemPressureState`.
- [ ] Confirm step-down: 540p → shorter buffer → capture off, all silent, game unaffected.
- [ ] No recording after `.critical`.

## Other
- [ ] Touch ID device: no Face ID assumptions anywhere.
- [ ] Inner display size classes (regular/regular) — every screen lays out.
- [ ] Idle timer disabled only during a round.
- [ ] All four languages: permission prompts (after relaunch), UI, word bank, CJK word fits on the lid ("陳奕迅", long English titles).
- [ ] Tick sound: audible with silent switch off, silent when on; toggle works.
