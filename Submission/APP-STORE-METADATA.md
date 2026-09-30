# App Store metadata — draft

| Field | Value |
|---|---|
| Name | CharaDUO (≤30 chars) |
| Subtitle | Party charades for iPhone Duo (≤30 chars) |
| Bundle ID | com.ryopang.partycharades (intentionally brand-neutral) |
| Primary category | Games → Party (Family/Word as secondary) |
| Age rating | 4+ (no objectionable content; camera is local-only) — answer the questionnaire honestly re: user-generated content = none |
| Price | Free, no IAP (v1) |
| Privacy label | Data Not Collected |
| Privacy manifest | `App/Resources/PrivacyInfo.xcprivacy` (UserDefaults CA92.1 only) |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` (no networking) |
| Localizations | en, zh-Hant (Taiwan), zh-Hans, zh-HK (Cantonese), ja |
| Support URL / Privacy policy URL | Draft in `docs/` (GitHub Pages) — enable Pages, then paste URLs; (privacy policy must state: no data collected, footage stays on device) |

## Description (English, draft)

Describe it. Guess it. Don't say the word.

CharaDUO is a party charades game built for the way people actually play:
standing up, phone flat on the table, everyone shouting.

• Pass-the-phone or tabletop — works on any iPhone, and on iPhone Duo the fold
  splits the screen: the describer's word on the lid, a scoreboard facing the
  guessers.
• 1,394 words across 10 categories — movies, TV, celebrities, animals, food,
  countries, sightseeing, superheroes, sport and brands.
• Words in English, Cantonese, Taiwan Mandarin, Mainland Mandarin and Japanese, with the
  whole app translated to match.
• Reaction Reel — the guessing team's best moments, replayed at 1×, 2× or 3×
  (chipmunk voices included) and saved to Photos if you want them.
• Private by design — video and audio never leave your phone. Unsaved clips are
  deleted when the match ends. The game plays fine with the camera off.

## Keywords (≤100 chars)

charades,party,game,guess,family,word,team,duo,friends,describe

## Screenshots needed (owner)
6.9" iPhone set + iPhone Duo inner-display set: Home, Quick Play round
(single-screen), tabletop lid + Correct/Skip, round summary, Game Over with reel.
Capture with `-uiTestPosture tabletop` / `-uiTestAutoStart` in the simulator, or
on hardware.
