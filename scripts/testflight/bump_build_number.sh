#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_FILE="${PROJECT_FILE:-$ROOT_DIR/Unstoppable.xcodeproj/project.pbxproj}"

current_build="$(grep -Eo 'CURRENT_PROJECT_VERSION = [0-9]+' "$PROJECT_FILE" | head -n 1 | awk '{print $3}')"

if [[ -z "${current_build:-}" ]]; then
  echo "Could not determine CURRENT_PROJECT_VERSION from $PROJECT_FILE" >&2
  exit 1
fi

next_build=$((current_build + 1))

perl -0pi -e "s/CURRENT_PROJECT_VERSION = ${current_build};/CURRENT_PROJECT_VERSION = ${next_build};/g" "$PROJECT_FILE"

echo "Build number bumped: ${current_build} -> ${next_build}"
