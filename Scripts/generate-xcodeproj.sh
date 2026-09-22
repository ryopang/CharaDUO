#!/bin/bash
# Regenerates PartyCharades.xcodeproj from project.yml via XcodeGen
# (https://github.com/yonaskolb/XcodeGen). Run this after editing project.yml,
# or after adding/removing/renaming source files under App/.
#
# XcodeGen isn't installed system-wide in this environment; this script
# fetches the prebuilt binary into a temp dir rather than requiring Homebrew.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="2.46.0"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN="xcodegen"
else
  curl -sL --max-time 60 -o "$WORKDIR/xcodegen.zip" \
    "https://github.com/yonaskolb/XcodeGen/releases/download/${VERSION}/xcodegen.zip"
  unzip -o -q "$WORKDIR/xcodegen.zip" -d "$WORKDIR"
  chmod +x "$WORKDIR/xcodegen/bin/xcodegen"
  xattr -cr "$WORKDIR/xcodegen" 2>/dev/null || true
  XCODEGEN="$WORKDIR/xcodegen/bin/xcodegen"
fi

"$XCODEGEN" generate
echo "Done. Review the diff in PartyCharades.xcodeproj before committing."
