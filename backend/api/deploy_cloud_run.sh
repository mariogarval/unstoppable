#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  backend/api/deploy_cloud_run.sh [PROJECT_ID]

Examples:
  backend/api/deploy_cloud_run.sh
  backend/api/deploy_cloud_run.sh unstoppable-app-dev

Optional environment variables:
  REGION=us-central1
  SERVICE_NAME=unstoppable-api
  ALLOW_UNAUTHENTICATED=0
  FIRESTORE_PROJECT=<defaults to PROJECT_ID>
  ALLOW_DEV_USER_HEADER=0
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ID="${1:-${PROJECT_ID:-unstoppable-app-dev}}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-unstoppable-api}"
ALLOW_UNAUTHENTICATED="${ALLOW_UNAUTHENTICATED:-0}"
FIRESTORE_PROJECT="${FIRESTORE_PROJECT:-$PROJECT_ID}"
ALLOW_DEV_USER_HEADER="${ALLOW_DEV_USER_HEADER:-0}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud CLI is required." >&2
  exit 1
fi

gcloud config set project "$PROJECT_ID" >/dev/null

deploy_cmd=(
  gcloud run deploy "$SERVICE_NAME"
  --project "$PROJECT_ID"
  --region "$REGION"
  --source "$SCRIPT_DIR"
  --platform managed
  --set-env-vars
  "GOOGLE_CLOUD_PROJECT=$FIRESTORE_PROJECT,ALLOW_DEV_USER_HEADER=$ALLOW_DEV_USER_HEADER"
)

if [[ "$ALLOW_UNAUTHENTICATED" == "1" ]]; then
  deploy_cmd+=(--allow-unauthenticated)
else
  deploy_cmd+=(--no-allow-unauthenticated)
fi

"${deploy_cmd[@]}"
