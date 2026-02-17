# Codex Logs Index

This folder tracks Codex session notes for backend work in this repository.

## Entries

### Session: `REVENUECAT_BACKEND_PHASE3_20260212.md` (2026-02-12)

WHAT was done:
- Added RevenueCat webhook endpoint with shared-secret auth and event-id idempotency.
- Persisted normalized subscription state in Firestore and exposed it in bootstrap response.
- Added `GET /v1/user/subscription` and `POST /v1/payments/subscription/snapshot`.
- Updated backend API docs for new payments routes and required env var.

KEY FILES modified:
- `/Users/luisgalvez/Projects/unstoppable/backend/api/src/app.py`
- `/Users/luisgalvez/Projects/unstoppable/backend/api/README.md`
- `/Users/luisgalvez/Projects/unstoppable/backend/codex_logs/REVENUECAT_BACKEND_PHASE3_20260212.md`
- `/Users/luisgalvez/Projects/unstoppable/backend/codex_logs/__CODEX_INDEX.md`

STATUS:
- Phase 3 backend webhook/subscription plumbing is implemented locally.
- Syntax checks passed; live endpoint runtime validation is pending environment setup/deploy.

KEY DECISIONS made:
- Enforce webhook auth using `REVENUECAT_WEBHOOK_AUTH`.
- Use Firestore create-once event documents to ignore duplicate webhook deliveries.
- Ignore out-of-order events to avoid stale subscription overwrite.

EXECUTED COMMANDS (with CLI args):
- `python3 -m py_compile backend/api/src/app.py`
- `rg -n "@app\.(get|post|put)\(\"/v1/(payments|user/subscription|bootstrap)" backend/api/src/app.py`
- `rg -n "REVENUECAT_WEBHOOK_AUTH|/v1/payments/revenuecat/webhook|/v1/payments/subscription/snapshot|/v1/user/subscription" backend/api/README.md`

### Session: `CLOUD_SETUP_20260212.md` (2026-02-12)

WHAT was done:
- Initialized Google Cloud project setup workflow and created deployment scripts for backend infrastructure.
- Implemented Python Cloud Run backend endpoints with Firestore persistence.
- Deployed the backend service and ran live smoke tests against v1 API routes.
- Extended `POST /v1/user/profile` to store terms-detail fields and paywall selection metadata.
- Redeployed Cloud Run and verified the new live revision/service URL.

KEY FILES modified:
- `/Users/luisgalvez/Projects/unstoppable/scripts/init_gcp_project.sh`
- `/Users/luisgalvez/Projects/unstoppable/backend/IMPLEMENTATION_PLAN.md`
- `/Users/luisgalvez/Projects/unstoppable/backend/api/src/app.py`
- `/Users/luisgalvez/Projects/unstoppable/backend/api/deploy_cloud_run.sh`
- `/Users/luisgalvez/Projects/unstoppable/backend/api/Dockerfile`
- `/Users/luisgalvez/Projects/unstoppable/backend/api/requirements.txt`
- `/Users/luisgalvez/Projects/unstoppable/backend/api/README.md`
- `/Users/luisgalvez/Projects/unstoppable/.gitignore`

STATUS:
- Backend service deployed to Cloud Run (`unstoppable-api`) in project `unstoppable-app-dev`.
- Firestore Native database created in `us-central1`.
- Endpoint smoke tests passed for all four v1 routes.
- Latest backend revision `unstoppable-api-00002-m25` is serving 100% traffic.

KEY DECISIONS made:
- Use Python (Flask + firebase-admin) on Cloud Run instead of Node.js.
- Use `unstoppable-app-dev` because `unstoppable-dev` was already taken globally.
- Use Firestore location `us-central1`.
- Enable temporary unauthenticated + dev-header mode only for smoke tests.
- Reuse `POST /v1/user/profile` for onboarding terms/payment metadata instead of creating a separate paywall endpoint at this stage.

EXECUTED COMMANDS (with CLI args):
- `BILLING_ACCOUNT=018AFD-E592F9-E4BF5A ./scripts/init_gcp_project.sh unstoppable-app-dev`
- `gcloud firestore databases create --location=us-central1 --type=firestore-native --project=unstoppable-app-dev`
- `ALLOW_UNAUTHENTICATED=1 ALLOW_DEV_USER_HEADER=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev`
- `curl -sS -i -X POST https://unstoppable-api-qri3urt3ha-uc.a.run.app/v1/user/profile -H 'Content-Type: application/json' -H 'X-User-Id: dev-user-001' -d '{"nickname":"Luis","ageGroup":"25-29","gender":"Male","notificationsEnabled":true,"termsAccepted":true}'`
- `curl -sS -i -X PUT https://unstoppable-api-qri3urt3ha-uc.a.run.app/v1/routines/current -H 'Content-Type: application/json' -H 'X-User-Id: dev-user-001' -d '{"routineTime":"07:00","tasks":[{"id":"t1","title":"Make bed","icon":"bed.double.fill","duration":2,"isCompleted":false}]}'`
- `curl -sS -i -X POST https://unstoppable-api-qri3urt3ha-uc.a.run.app/v1/progress/daily -H 'Content-Type: application/json' -H 'X-User-Id: dev-user-001' -d '{"date":"2026-02-12","completed":1,"total":1,"completedTaskIds":["t1"]}'`
- `curl -sS -i https://unstoppable-api-qri3urt3ha-uc.a.run.app/v1/bootstrap -H 'X-User-Id: dev-user-001'`
- `ALLOW_UNAUTHENTICATED=1 ALLOW_DEV_USER_HEADER=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev`
