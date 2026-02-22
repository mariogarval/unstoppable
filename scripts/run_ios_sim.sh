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
  STOREKIT_MODE=auto   # auto|required|off
  STOREKIT_CONFIG_PATH=/absolute/or/project-relative/path/to.storekit
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
STOREKIT_MODE="${STOREKIT_MODE:-auto}"
STOREKIT_CONFIG_PATH="${STOREKIT_CONFIG_PATH:-}"

case "$STOREKIT_MODE" in
  auto|required|off) ;;
  *)
    echo "Invalid STOREKIT_MODE: $STOREKIT_MODE (expected: auto|required|off)" >&2
    exit 1
    ;;
esac

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project not found: $PROJECT_PATH" >&2
  exit 1
fi

normalize_path() {
  local raw="$1"
  if [[ -z "$raw" ]]; then
    return 1
  fi
  if [[ "$raw" = /* ]]; then
    printf '%s' "$raw"
  else
    printf '%s' "$ROOT_DIR/$raw"
  fi
}

resolve_scheme_storekit_config() {
  local scheme_path="$ROOT_DIR/Unstoppable.xcodeproj/xcshareddata/xcschemes/${SCHEME}.xcscheme"
  if [[ ! -f "$scheme_path" ]]; then
    return 1
  fi

  local identifier=""
  identifier="$(awk '
    /StoreKitConfigurationFileReference/ { in_node=1 }
    in_node && /identifier = "/ {
      if (match($0, /identifier = "[^"]+"/)) {
        val=substr($0, RSTART, RLENGTH)
        gsub(/^identifier = "/, "", val)
        gsub(/"$/, "", val)
        print val
        exit
      }
    }
    in_node && /<\/StoreKitConfigurationFileReference>/ { in_node=0 }
  ' "$scheme_path")"
  if [[ -z "$identifier" ]]; then
    return 1
  fi

  if [[ "$identifier" = /* ]]; then
    printf '%s' "$identifier"
    return 0
  fi

  # Xcode stores this relative to the .xcodeproj directory.
  local project_dir
  project_dir="$(cd "$(dirname "$(dirname "$(dirname "$scheme_path")")")" && pwd)"
  local from_project_dir="$project_dir/$identifier"
  if [[ -f "$from_project_dir" ]]; then
    printf '%s' "$from_project_dir"
    return 0
  fi

  # Some setups may store it relative to the .xcscheme location.
  local scheme_dir
  scheme_dir="$(cd "$(dirname "$scheme_path")" && pwd)"
  local from_scheme_dir="$scheme_dir/$identifier"
  if [[ -f "$from_scheme_dir" ]]; then
    printf '%s' "$from_scheme_dir"
    return 0
  fi

  # Fallback for repo-root-relative paths.
  local from_root="$ROOT_DIR/$identifier"
  if [[ -f "$from_root" ]]; then
    printf '%s' "$from_root"
    return 0
  fi

  # Return project-relative candidate for diagnostics.
  printf '%s' "$from_project_dir"
}

print_storekit_status() {
  local explicit_path="$1"
  local scheme_path="$2"
  local active_path="$3"

  if [[ "$STOREKIT_MODE" == "off" ]]; then
    echo "StoreKit mode: off"
    return 0
  fi

  if [[ -n "$scheme_path" && -f "$scheme_path" ]]; then
    echo "StoreKit config (scheme): $scheme_path"
  elif [[ -n "$scheme_path" ]]; then
    echo "StoreKit config (scheme): $scheme_path (missing)"
  else
    echo "StoreKit config (scheme): not set in ${SCHEME}.xcscheme"
  fi

  if [[ -n "$explicit_path" ]]; then
    if [[ -f "$explicit_path" ]]; then
      echo "StoreKit config (override): $explicit_path"
    else
      echo "StoreKit config (override): $explicit_path (missing)"
    fi
  fi

  if [[ -n "$active_path" ]]; then
    echo "StoreKit mode: $STOREKIT_MODE (active config: $active_path)"
  else
    echo "StoreKit mode: $STOREKIT_MODE (no active config)"
  fi

  if [[ "$STOREKIT_MODE" != "off" ]]; then
    echo "Note: simctl launch cannot force StoreKit config on this Xcode CLI."
    echo "For guaranteed local StoreKit behavior, run the app from Xcode with the scheme StoreKit config enabled."
  fi
}

SCHEME_STOREKIT_CONFIG_PATH="$(resolve_scheme_storekit_config || true)"
EXPLICIT_STOREKIT_CONFIG_PATH="$(normalize_path "$STOREKIT_CONFIG_PATH" || true)"
ACTIVE_STOREKIT_CONFIG_PATH="$SCHEME_STOREKIT_CONFIG_PATH"
if [[ -n "$EXPLICIT_STOREKIT_CONFIG_PATH" ]]; then
  ACTIVE_STOREKIT_CONFIG_PATH="$EXPLICIT_STOREKIT_CONFIG_PATH"
fi

if [[ "$STOREKIT_MODE" == "required" ]]; then
  if [[ -z "$ACTIVE_STOREKIT_CONFIG_PATH" || ! -f "$ACTIVE_STOREKIT_CONFIG_PATH" ]]; then
    echo "STOREKIT_MODE=required but no valid StoreKit config file is available." >&2
    echo "Set STOREKIT_CONFIG_PATH or configure StoreKitConfigurationFileReference in ${SCHEME}.xcscheme." >&2
    exit 1
  fi
fi

print_storekit_status "$EXPLICIT_STOREKIT_CONFIG_PATH" "$SCHEME_STOREKIT_CONFIG_PATH" "$ACTIVE_STOREKIT_CONFIG_PATH"

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

find_latest_built_app() {
  local -a candidates=()
  local preferred="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphonesimulator/${SCHEME}.app"
  if [[ -d "$preferred" ]]; then
    candidates+=("$preferred")
  fi

  while IFS= read -r app; do
    [[ -d "$app" ]] && candidates+=("$app")
  done < <(find "$DERIVED_DATA_PATH/Build/Products" -maxdepth 2 -type d -name '*.app' 2>/dev/null || true)

  while IFS= read -r app; do
    [[ -d "$app" ]] && candidates+=("$app")
  done < <(find "$HOME/Library/Developer/Xcode/DerivedData" \
    -path "*/Build/Products/${CONFIGURATION}-iphonesimulator/${SCHEME}.app" \
    -type d 2>/dev/null || true)

  if [[ "${#candidates[@]}" -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${candidates[@]}" \
    | awk '!seen[$0]++' \
    | while IFS= read -r app; do
        printf '%s|%s\n' "$(stat -f '%m' "$app" 2>/dev/null || echo 0)" "$app"
      done \
    | sort -t'|' -nr -k1,1 \
    | head -n 1 \
    | cut -d'|' -f2-
}

APP_PATH="$(find_latest_built_app || true)"

if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
  echo "Could not locate built app for scheme '$SCHEME'." >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
echo "Installing app: $APP_PATH"
xcrun simctl install "$SIM_ID" "$APP_PATH"
echo "Launching bundle id: $BUNDLE_ID"
xcrun simctl launch "$SIM_ID" "$BUNDLE_ID"
