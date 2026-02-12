#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/run_ios_sim.sh "<SIM_NAME>"

Example:
  scripts/run_ios_sim.sh "iPhone 17 Pro"

Optional env vars:
  SCHEME=Unstoppable
  CONFIGURATION=Debug
  DERIVED_DATA_PATH=/path/to/.build
  OPEN_SIMULATOR_APP=1
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

SIM_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_PATH="$ROOT_DIR/Unstoppable.xcodeproj"
SCHEME="${SCHEME:-Unstoppable}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build}"
OPEN_SIMULATOR_APP="${OPEN_SIMULATOR_APP:-1}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project not found: $PROJECT_PATH" >&2
  exit 1
fi

resolve_sim_id() {
  local wanted_name="$1"
  local sim_name=""
  local sim_id=""

  while IFS='|' read -r sim_name sim_id; do
    if [[ "$sim_name" == "$wanted_name" ]]; then
      printf '%s' "$sim_id"
      return 0
    fi
  done < <(
    xcrun simctl list devices available \
      | sed -nE '/unavailable/!s/^[[:space:]]*(.*) \(([0-9A-Fa-f-]{36})\) \([^)]+\)[[:space:]]*$/\1|\2/p'
  )

  return 1
}

SIM_ID="$(resolve_sim_id "$SIM_NAME" || true)"
if [[ -z "$SIM_ID" ]]; then
  echo "Simulator not found: $SIM_NAME" >&2
  echo "Available simulator names:" >&2
  xcrun simctl list devices available | sed -nE 's/^[[:space:]]{4,}(.+) \([0-9A-Fa-f-]{36}\) \([^)]+\)[[:space:]]*$/\1/p' | sort -u >&2
  exit 1
fi

echo "Using simulator: $SIM_NAME ($SIM_ID)"
if [[ "$OPEN_SIMULATOR_APP" == "1" ]]; then
  # Bring Simulator UI to front and focus the selected device.
  open -a Simulator --args -CurrentDeviceUDID "$SIM_ID" >/dev/null 2>&1 || true
fi
xcrun simctl boot "$SIM_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_ID" -b

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "id=$SIM_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphonesimulator/${SCHEME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products" -maxdepth 2 -type d -name '*.app' | head -n 1)"
fi

if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
  echo "Could not locate built app in: $DERIVED_DATA_PATH/Build/Products" >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
echo "Installing app: $APP_PATH"
xcrun simctl install "$SIM_ID" "$APP_PATH"
echo "Launching bundle id: $BUNDLE_ID"
xcrun simctl launch "$SIM_ID" "$BUNDLE_ID"
