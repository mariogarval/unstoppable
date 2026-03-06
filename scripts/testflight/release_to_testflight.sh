#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

"$ROOT_DIR/scripts/testflight/archive_app.sh"
"$ROOT_DIR/scripts/testflight/export_ipa.sh"
"$ROOT_DIR/scripts/testflight/upload_ipa.sh"
