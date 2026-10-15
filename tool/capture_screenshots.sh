#!/usr/bin/env bash
# Regenerates the phone screenshots (390x844 logical, 3x) with Roboto and
# Material Icons. Writes PNGs to SCREENSHOT_DIR, or to
# /opt/cursor/artifacts/screenshots when that directory's parent exists.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [[ -z "${FLUTTER_ROOT:-}" ]]; then
  flutter_bin="$(command -v flutter)"
  FLUTTER_ROOT="$(cd "$(dirname "$flutter_bin")/.." && pwd)"
  export FLUTTER_ROOT
fi

if [[ -z "${SCREENSHOT_DIR:-}" ]]; then
  if [[ -d /opt/cursor/artifacts ]]; then
    SCREENSHOT_DIR=/opt/cursor/artifacts/screenshots
  else
    SCREENSHOT_DIR="$root/build/screenshots"
  fi
  export SCREENSHOT_DIR
fi

mkdir -p "$SCREENSHOT_DIR"
flutter test test/screenshots_test.dart
echo "Screenshots written to $SCREENSHOT_DIR"
