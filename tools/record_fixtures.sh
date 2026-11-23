#!/usr/bin/env bash
# Fills in the `expected` half of shared/fixtures/ by running the real iOS
# implementations over the inputs, and exports shared/data/glossary.json.
#
# The expected values are recorded from the shipped behaviour, never written
# by hand: whatever iOS actually does is the contract Android has to meet.
#
# Usage: tools/record_fixtures.sh [simulator-name]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="org.finalstretch.rxcall"
SIM_NAME="${1:-iPhone 17 Pro}"
BUILD_DIR="$(mktemp -d)"

DEVICE=$(xcrun simctl list devices available \
  | grep -F "$SIM_NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$DEVICE" ] || { echo "No simulator named '$SIM_NAME'." >&2; exit 1; }

echo "Building for ${SIM_NAME}…"
xcodebuild -project "$REPO/ios/Rxcall/Rxcall.xcodeproj" -scheme Rxcall \
  -destination "id=$DEVICE" -configuration Debug \
  -derivedDataPath "$BUILD_DIR" build > "$BUILD_DIR/build.log" 2>&1 \
  || { tail -30 "$BUILD_DIR/build.log"; exit 1; }

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl install "$DEVICE" \
  "$BUILD_DIR/Build/Products/Debug-iphonesimulator/Rxcall.app"

# A simulator app can't read the repo, so the fixtures go in and come back
# through its own Documents directory.
DOCS="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data)/Documents"
mkdir -p "$DOCS"
rm -rf "$DOCS/fixtures" "$DOCS/done.txt" "$DOCS/glossary.json"
cp -R "$REPO/shared/fixtures" "$DOCS/fixtures"

echo "Recording…"
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -record-fixtures > /dev/null

for _ in $(seq 1 60); do
  [ -f "$DOCS/done.txt" ] && break
  xcrun simctl spawn "$DEVICE" log show --last 1s --predicate 'process == "nothing"' > /dev/null 2>&1
done
[ -f "$DOCS/done.txt" ] || { echo "Recorder never finished." >&2; exit 1; }

cat "$DOCS/done.txt"
cp -R "$DOCS/fixtures/." "$REPO/shared/fixtures/"
cp "$DOCS/glossary.json" "$REPO/shared/data/glossary.json"
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
rm -rf "$BUILD_DIR"
echo "Recorded into shared/fixtures and shared/data/glossary.json."
