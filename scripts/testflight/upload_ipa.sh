#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/testflight-export}"
IPA_PATH="${IPA_PATH:-$EXPORT_PATH/Unstoppable.ipa}"
BUNDLE_ID="${BUNDLE_ID:-app.unstoppable.unstoppable}"
APP_STORE_CONNECT_APP_ID="${APP_STORE_CONNECT_APP_ID:-6759273918}"
API_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-}"
API_ISSUER_ID="${APP_STORE_CONNECT_API_ISSUER_ID:-}"
API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-}"

if [[ -z "$API_KEY_ID" ]]; then
  echo "Missing APP_STORE_CONNECT_API_KEY_ID" >&2
  exit 1
fi

if [[ -z "$API_ISSUER_ID" ]]; then
  echo "Missing APP_STORE_CONNECT_API_ISSUER_ID" >&2
  exit 1
fi

if [[ -z "$API_KEY_PATH" ]]; then
  API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"
fi

if [[ ! -f "$IPA_PATH" ]]; then
  echo "IPA not found at $IPA_PATH" >&2
  exit 1
fi

if [[ ! -f "$API_KEY_PATH" ]]; then
  echo "API key file not found at $API_KEY_PATH" >&2
  exit 1
fi

export API_PRIVATE_KEYS_DIR
API_PRIVATE_KEYS_DIR="$(dirname "$API_KEY_PATH")"

xcrun altool \
  --upload-package "$IPA_PATH" \
  --platform ios \
  --apple-id "$APP_STORE_CONNECT_APP_ID" \
  --api-key "$API_KEY_ID" \
  --api-issuer "$API_ISSUER_ID" \
  --show-progress \
  --output-format normal
