#!/bin/zsh
# Capture App Store screenshots from the simulator with the -uiTest* flags.
#   Scripts/capture-screenshots.sh [device name] [languages...]
# Default: iPhone 17 Pro Max (6.9"), en zh-Hant zh-Hans zh-HK ja.
# Output: Submission/screenshots/<device>/<lang>/<scene>.png
# The Duo inner display: capture that set by hand from the Device Hub window
# (simctl framebuffer captures of the Duo panel are unreliable — see CLAUDE.md).
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE=${1:-"iPhone 17 Pro Max"}; shift || true
# Two simulators can share a name (there are two "iPhone Duo"); accept a UDID,
# or resolve a name to the first matching device.
if [[ "$DEVICE" != *-*-*-*-* ]]; then
  NAME="$DEVICE"
  DEVICE=$(xcrun simctl list devices available | grep -F "$NAME (" | head -1 | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}')
else
  NAME=$(xcrun simctl list devices | grep "$DEVICE" | head -1 | sed -E "s/^ +//; s/ \(.*//")
fi
LANGS=("$@"); (( ${#LANGS} )) || LANGS=(en zh-Hant zh-Hans zh-HK ja)
BUNDLE=com.ryopang.partycharades
DD="${TMPDIR:-/tmp}/dd-shots"
OUT="Submission/screenshots/${NAME// /-}"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcodebuild build -project PartyCharades.xcodeproj -scheme PartyCharades -configuration Debug \
  -destination "id=$DEVICE" -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO -quiet
xcrun simctl install "$DEVICE" "$DD/Build/Products/Debug-iphonesimulator/PartyCharades.app"
xcrun simctl status_bar "$DEVICE" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true

shot() { # lang scene delay extra-args...
  local lang=$1 scene=$2 delay=$3; shift 3
  mkdir -p "$OUT/$lang"
  xcrun simctl terminate "$DEVICE" $BUNDLE 2>/dev/null || true
  xcrun simctl launch "$DEVICE" $BUNDLE -AppleLanguages "($lang)" -AppleLocale "${lang//-/_}" \
    -uiTestSkipConsent -uiTestResetAppLanguage "$@" >/dev/null
  sleep "$delay"
  xcrun simctl io "$DEVICE" screenshot "$OUT/$lang/$scene.png" >/dev/null 2>&1
  echo "  $lang/$scene"
}

outer_uuid() { # the 1398x2034 display is the outer panel
  xcrun simctl io "$DEVICE" enumerate 2>/dev/null | awk '/UUID:/{u=$2} /Default width: 1398/{print u; exit}'
}
if [[ "$NAME" == *Duo* ]]; then
  # Duo: set the tabletop pose ONCE in Device Hub (Xcode.app, not Xcode-beta),
  # using the middle posture button at the bottom of the window. No posture
  # override here, so the real hinge path is what gets captured.
  for lang in $LANGS; do
    shot $lang 01-home 3
    shot $lang 02-tabletop-round 8 -uiTestAutoStart -uiTestSyntheticCamera -uiTestCaptureState full
    # Outer display = the guessers' scoreboard, quarter-turned by design.
    # Verified 2026-09-30 (Xcode 27.1): the raw framebuffer already matches how
    # the layout is turned (REC bottom-right); no extra 180deg flip needed.
    xcrun simctl io "$DEVICE" screenshot --display="$(outer_uuid)" "$OUT/$lang/03-outer-display.png" >/dev/null 2>&1
    echo "  $lang/03-outer-display"
  done
else
  for lang in $LANGS; do
    shot $lang 01-home 3
    shot $lang 02-round 4 -uiTestAutoStart -uiTestPosture noHinge
  done
fi
xcrun simctl status_bar "$DEVICE" clear >/dev/null 2>&1 || true
echo "Done → $OUT"
