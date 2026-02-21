# Backend Identity Canonicalization and Profile Completion

**Date**: 2026-02-21
**Status**: Complete
**Branch**: `codex/apple-auth-firebase`
**Author**: Codex (GPT-5)

---

## Summary

Implemented canonical user resolution for bearer-authenticated requests using verified email alias mapping, added explicit profile completion outputs in bootstrap responses, deployed the backend, and verified runtime behavior through Cloud Run proxy checks.

---

## Problem Statement

Google and Apple sign-ins for the same email risked creating separate backend user records, and onboarding route decisions needed deterministic completion state from backend data.

---

## Changes Made

### 1. Added canonical identity resolution in auth path

Resolved request user IDs through verified-email alias documents and UID alias tracking.

**Files Created/Modified**:
- `backend/api/src/app.py` - added canonicalization helpers and request user-resolution updates.

### 2. Added profile completion computation and response fields

Computed required profile completeness and returned structured completion metadata from bootstrap.

**Files Created/Modified**:
- `backend/api/src/app.py` - added `_profile_completion`, `isProfileComplete`, and `profileCompletion` response fields.

### 3. Aligned webhook identity writes

Resolved incoming webhook `app_user_id` through UID alias mapping before subscription writes.

**Files Created/Modified**:
- `backend/api/src/app.py` - webhook identity normalization updates.

### 4. Updated backend docs and scoped memory

Documented canonicalization/completion behavior and migrated this session record to backend `agent_logs`.

**Files Created/Modified**:
- `backend/api/README.md`
- `backend/agent_logs/IDENTITY_CANONICALIZATION_PROFILE_COMPLETION_20260221.md`
- `backend/agent_logs/__AGENT_INDEX.md`

---

## Key Results

- Backend now supports canonical identity mapping for same-email provider sign-ins (verified email).
- Bootstrap includes explicit completion contract fields consumed by app routing.
- Deployed Cloud Run revision reached 100% traffic and runtime checks validated completion behavior.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Canonicalize only on verified email | Avoids unsafe merges for unverified identities. |
| Keep fallback to raw UID on alias errors | Prevents auth-path outages when alias reads/writes fail. |
| Define completion with required fields (`nickname`, `notificationsEnabled`, `termsAccepted`, `termsOver16Accepted`, `paymentOption`) | Matches onboarding contract used by app routing. |
| Preserve raw webhook `app_user_id` alongside canonical write target | Retains traceability while normalizing user storage. |

---

## Verification

```bash
python3 -m py_compile /Users/luisgalvez/Projects/unstoppable/backend/api/src/app.py
rg -n "isProfileComplete|profileCompletion|user_email_aliases|user_uid_aliases|_resolve_canonical_user_id" /Users/luisgalvez/Projects/unstoppable/backend/api/src/app.py
backend/api/deploy_cloud_run.sh unstoppable-app-dev
ALLOW_UNAUTHENTICATED=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev
ALLOW_UNAUTHENTICATED=1 ALLOW_DEV_USER_HEADER=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev
ALLOW_UNAUTHENTICATED=1 ALLOW_DEV_USER_HEADER=0 backend/api/deploy_cloud_run.sh unstoppable-app-dev
gcloud run services proxy unstoppable-api --project unstoppable-app-dev --region us-central1 --port 8081
curl -sS -i --max-time 20 -H 'X-User-Id: dev-profile-check-20260221' http://127.0.0.1:8081/v1/bootstrap
curl -sS -i --max-time 20 -X POST -H 'Content-Type: application/json' -H 'X-User-Id: dev-profile-check-20260221' -d '{"nickname":"Test User"}' http://127.0.0.1:8081/v1/user/profile
curl -sS -i --max-time 20 -X POST -H 'Content-Type: application/json' -H 'X-User-Id: dev-profile-check-20260221' -d '{"notificationsEnabled":true,"termsAccepted":true,"termsOver16Accepted":true,"paymentOption":"annual"}' http://127.0.0.1:8081/v1/user/profile
gcloud run services describe unstoppable-api --project unstoppable-app-dev --region us-central1 --format='yaml(status.latestReadyRevisionName,status.latestCreatedRevisionName,status.traffic,status.url)'
```

- [x] Local syntax validation passed.
- [x] Deployment completed to ready revision with full traffic.
- [x] Runtime completion behavior validated via proxy.
- [x] Temporary dev-header verification path re-disabled after checks.

---

## Next Steps

- Run real Google and Apple same-email sign-in verification with live Firebase tokens to confirm canonical user ID continuity end-to-end.

---

## Related Documents

- `Unstoppable/agent_logs/PROFILE_COMPLETION_ROUTING_20260221.md` - app-side routing consumer.
- `agent_logs/APPLE_AUTH_FIREBASE_ROLLOUT_20260221.md` - auth rollout context.
