#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/init_gcp_project.sh [PROJECT_ID]

Examples:
  scripts/init_gcp_project.sh
  scripts/init_gcp_project.sh unstoppable-dev
  BILLING_ACCOUNT=000000-111111-222222 scripts/init_gcp_project.sh

Optional environment variables:
  PROJECT_NAME            Human-friendly project name (default: "Unstopable Dev")
  BILLING_ACCOUNT         Billing account ID to link after project creation
  FOLDER_ID               GCP Folder ID (mutually exclusive with ORG_ID)
  ORG_ID                  GCP Organization ID (mutually exclusive with FOLDER_ID)
  ENABLE_APIS             1 to enable backend APIs (default: 1)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

PROJECT_ID="${1:-${PROJECT_ID:-unstoppable-dev}}"
PROJECT_NAME="${PROJECT_NAME:-Unstoppable Dev}"
BILLING_ACCOUNT="${BILLING_ACCOUNT:-}"
FOLDER_ID="${FOLDER_ID:-}"
ORG_ID="${ORG_ID:-}"
ENABLE_APIS="${ENABLE_APIS:-1}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud CLI is required. Install it first: https://cloud.google.com/sdk/docs/install" >&2
  exit 1
fi

if [[ -n "$FOLDER_ID" && -n "$ORG_ID" ]]; then
  echo "Set only one of FOLDER_ID or ORG_ID." >&2
  exit 1
fi

ACTIVE_ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
if [[ -z "$ACTIVE_ACCOUNT" ]]; then
  echo "No active gcloud account found. Run: gcloud auth login" >&2
  exit 1
fi

echo "Using gcloud account: $ACTIVE_ACCOUNT"
echo "Target project: $PROJECT_ID"

if gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
  echo "Project already exists: $PROJECT_ID"
else
  echo "Creating project: $PROJECT_ID"
  create_cmd=(gcloud projects create "$PROJECT_ID" --name="$PROJECT_NAME")
  if [[ -n "$FOLDER_ID" ]]; then
    create_cmd+=("--folder=$FOLDER_ID")
  elif [[ -n "$ORG_ID" ]]; then
    create_cmd+=("--organization=$ORG_ID")
  fi
  "${create_cmd[@]}"
fi

gcloud config set project "$PROJECT_ID" >/dev/null
echo "Set active gcloud project to: $PROJECT_ID"

if [[ -n "$BILLING_ACCOUNT" ]]; then
  echo "Linking billing account: $BILLING_ACCOUNT"
  gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
else
  echo "BILLING_ACCOUNT not provided. Skipping billing link."
fi

if [[ "$ENABLE_APIS" == "1" ]]; then
  echo "Enabling core APIs for the Unstoppable backend..."
  gcloud services enable \
    run.googleapis.com \
    firestore.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    cloudtasks.googleapis.com \
    logging.googleapis.com \
    monitoring.googleapis.com \
    iam.googleapis.com \
    --project "$PROJECT_ID"
fi

cat <<EOF

Initialization complete.

Project ID: $PROJECT_ID
Next steps:
1) (If needed) link billing:
   gcloud billing projects link $PROJECT_ID --billing-account=YOUR_BILLING_ACCOUNT
2) Create Firestore database (one-time):
   gcloud firestore databases create --location=us-central --type=firestore-native --project=$PROJECT_ID
3) Deploy your first Cloud Run API service.
EOF
