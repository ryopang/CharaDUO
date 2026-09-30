# App Review Notes — CharaDUO 1.3.1

Paste into App Store Connect → App Review Information → Notes. No sign-in is
required; the app has no accounts and no network access.

---

CharaDUO is a party charades game. One player describes a word without saying
it; their team guesses; taps on the device score it. It is designed for iPhone
Duo's tabletop posture but is **fully playable on any iPhone** — please review
it on a standard iPhone; nothing in the core game requires special hardware.

**Why the camera and microphone.** During a live round the app records the
guessing team's reactions (video) and the table (audio) to build a short
"reaction reel" the players watch, and can optionally save, when the match ends.
On iPhone Duo, an active capture session is also what lets the system show the
scoreboard on the outer display (`CameraCaptureAccessory`); that is a secondary
benefit, not the reason for the capture.

**Privacy.**
- Audio and video never leave the device. There is no networking code, no
  analytics, no speech recognition and no third-party SDK anywhere in the app.
- Footage lives in a temporary directory only. Anything not saved is deleted
  when the match is left, and the directory is purged again at every launch.
- Photos access is requested only when the player taps Save.
- App Privacy label: **Data Not Collected**.
- In-app purchases: the first 10 games are free; "10 More Games" (consumable) and
  "Unlimited Games" (non-consumable) are offered when they run out, or any time from the
  gear icon → Games. Restore Purchases is on the paywall and in Settings. Purchases are
  handled on-device with StoreKit 2; no account or server is involved.

**Consent.** Before the first match every player sees a card stating plainly
that the guessing team is filmed and the table is recorded with sound, that
everything stays on the device, and that it can be turned off. Camera and
microphone are requested together on that card, never mid-round. A recording
indicator ("REC") is visible on the inner display and, on iPhone Duo, the outer
display for as long as recording is active.

**Fully functional without camera/microphone.** Tapping "Play Without It" — or
denying either permission — leaves the whole game playable. Denying the
microphone only removes sound from the reel. Settings has a Reaction Camera
master switch and a Record Sound switch.

**Testing without an iPhone Duo.** On a standard iPhone the game uses a
single-screen layout: the top half shows the word and countdown, the bottom
half has large Skip / Correct zones. No camera session is started on
non-Duo hardware, so the camera indicator never lights there. Tap **Quick
Play** for an instant 2-team match.

**Languages.** English, Cantonese (Hong Kong), Traditional Chinese (Taiwan),
Simplified Chinese (Mainland) and Japanese. The in-app language setting (gear icon on the
Home screen) changes the word bank and the interface together.

**Name.** The app name is "CharaDUO". "Duo" is used descriptively to refer to
the iPhone Duo device the game is built for; we are aware of Guideline 5.2.1 and
have kept the name distinct from Apple's marks. If you have concerns about the
name we would like to discuss them rather than reject — please contact us.

**Demo video.** A recording of tabletop gameplay on iPhone Duo (two-sided
layout, outer-display scoreboard for the guessers, reaction
reel) is attached, since the two-sided layout is the part that needs seeing.
