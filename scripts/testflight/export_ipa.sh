#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/Unstoppable.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/testflight-export}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT_DIR/scripts/testflight/ExportOptions.plist}"

xcodebuild \
  -exportArchive \
  -allowProvisioningUpdates \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
