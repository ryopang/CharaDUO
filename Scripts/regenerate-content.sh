#!/bin/bash
# Regenerates Packages/Content/Sources/Content/Resources/vocabulary.json from
# Multilingual_Vocabulary_1100.xlsx via the xlsx2json build tool (PRD §6.3).
#
# Run this whenever the source spreadsheet changes. It is NOT part of the app
# build itself — the .xlsx is a build-time-of-the-tool input, never read by
# the app at runtime (CLAUDE.md §4). Wiring this into an Xcode Run Script /
# build tool plugin so *validation* re-runs on every app build is M3+ work;
# for now, run manually and commit the regenerated JSON.
set -euo pipefail
cd "$(dirname "$0")/.."

XLSX="$(pwd)/Multilingual_Vocabulary_1100.xlsx"
OUTPUT="$(pwd)/Packages/Content/Sources/Content/Resources/vocabulary.json"

# This project directory is iCloud-synced; iCloud's file-provider extension
# tags freshly-built SPM output with FinderInfo/file-provider xattrs that
# break `codesign`. Build outside the synced tree to avoid it.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

swift build --package-path Packages/ContentPipeline --scratch-path "$SCRATCH" -c release
"$SCRATCH/release/xlsx2json" "$XLSX" "$OUTPUT"

# Files this script writes/touches also pick up the same xattr; strip it so a
# later `swift build`/`swift test` on the resource doesn't fail codesign.
xattr -c "$OUTPUT" 2>/dev/null || true

echo "Done. Review the diff in $OUTPUT before committing."
