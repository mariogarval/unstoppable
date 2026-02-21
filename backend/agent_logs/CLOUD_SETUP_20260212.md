# Cloud Backend Setup

**Date**: 2026-02-12
**Status**: Complete
**Branch**: `add-flow-docs`
**Author**: Codex (GPT-5)

---

## Summary

Established the initial Google Cloud backend foundation for Unstoppable, including project/bootstrap automation, Flask API scaffold, Firestore provisioning, Cloud Run deployment, and endpoint smoke tests.

---

## Problem Statement

The app required a deployable backend with durable storage and basic sync endpoints for profile, routine, progress, and bootstrap data.

---

## Changes Made

### 1. Added cloud project initialization automation

Created helper script to initialize project-level dependencies and API enablement.

**Files Created/Modified**:
- `scripts/init_gcp_project.sh`

### 2. Defined backend architecture and rollout plan

Expanded implementation plan to describe selected GCP stack and rollout sequencing.

**Files Created/Modified**:
- `backend/IMPLEMENTATION_PLAN.md`

### 3. Implemented Python backend service scaffold

Switched backend scaffold to Flask + Firestore with container/runtime dependencies.

**Files Created/Modified**:
- `backend/api/src/app.py`
- `backend/api/deploy_cloud_run.sh`
- `backend/api/Dockerfile`
- `backend/api/requirements.txt`
- `backend/api/README.md`

### 4. Deployed and smoke-tested v1 endpoints

Deployed to Cloud Run and verified profile/routine/progress/bootstrap requests.

**Files Created/Modified**:
- `backend/api/src/app.py` (iterative endpoint updates)

### 5. Updated scoped backend memory

Migrated this session record and index to scoped backend `agent_logs`.

**Files Created/Modified**:
- `backend/agent_logs/CLOUD_SETUP_20260212.md`
- `backend/agent_logs/__AGENT_INDEX.md`

---

## Key Results

- Cloud Run service `unstoppable-api` deployed in `unstoppable-app-dev`.
- Firestore Native database provisioned in `us-central1`.
- Core endpoint smoke tests passed for profile/routine/progress/bootstrap.
- Profile allowlist expanded to include `termsOver16Accepted`, `termsMarketingAccepted`, and `paymentOption`.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Use Flask + firebase-admin on Cloud Run | Fast setup path with native Firestore integration. |
| Use Firestore Native in `us-central1` | Regional alignment with initial backend deployment. |
| Allow temporary unauth/dev-header mode for smoke tests | Enabled rapid endpoint validation during early rollout. |

---

## Verification

```bash
BILLING_ACCOUNT=018AFD-E592F9-E4BF5A ./scripts/init_gcp_project.sh unstoppable-app-dev
gcloud firestore databases create --location=us-central1 --type=firestore-native --project=unstoppable-app-dev
ALLOW_UNAUTHENTICATED=1 ALLOW_DEV_USER_HEADER=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev
curl -sS -i -X POST https://unstoppable-api-qri3urt3ha-uc.a.run.app/v1/user/profile -H 'Content-Type: application/json' -H 'X-User-Id: dev-user-001' -d '{"nickname":"Luis","ageGroup":"25-29","gender":"Male","notificationsEnabled":true,"termsAccepted":true}'
curl -sS -i -X PUT https://unstoppable-api-qri3urt3ha-uc.a.run.app/v1/routines/current -H 'Content-Type: application/json' -H 'X-User-Id: dev-user-001' -d '{"routineTime":"07:00","tasks":[{"id":"t1","title":"Make bed","icon":"bed.double.fill","duration":2,"isCompleted":false}]}'
curl -sS -i -X POST https://unstoppable-api-qri3urt3ha-uc.a.run.app/v1/progress/daily -H 'Content-Type: application/json' -H 'X-User-Id: dev-user-001' -d '{"date":"2026-02-12","completed":1,"total":1,"completedTaskIds":["t1"]}'
curl -sS -i https://unstoppable-api-qri3urt3ha-uc.a.run.app/v1/bootstrap -H 'X-User-Id: dev-user-001'
```

- [x] Firestore database created.
- [x] Cloud Run deploy completed.
- [x] Core endpoint smoke tests passed.

---

## Next Steps

- Continue hardening auth mode defaults and rollout-safe configuration.
- Expand payments/auth integration phases on top of deployed baseline.

---

## Related Documents

- `backend/agent_logs/REVENUECAT_BACKEND_PHASE3_20260212.md` - later backend payments webhook/subscription extensions.
- `backend/agent_logs/IDENTITY_CANONICALIZATION_PROFILE_COMPLETION_20260221.md` - later auth model evolution.
