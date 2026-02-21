# Auth Bootstrap and Profile Sync Hardening

**Date**: 2026-02-21
**Status**: Complete
**Branch**: `codex/apple-auth-firebase`
**Author**: Codex (GPT-5)

---

## Summary

This session closed the auth/bootstrap reliability loop across iOS and backend after Google/Apple sign-in rollout. The final fixes and verification established stable Bearer-token bootstrap behavior, deterministic profile completion routing, and practical reset tooling for repeatable onboarding tests.

---

## Problem Statement

After auth rollout, sign-in could succeed while account bootstrap failed, showing: `Signed in, but failed to load your account. Please try again.` In parallel, onboarding answers were not always reflected in Firestore during retests, and existing profile data masked whether routing and profile persistence were actually correct.

---

## Changes Made

### 1. Backend auth path hardening and canonical identity behavior

Finalized backend auth behavior for Firebase token verification and canonical user resolution, then deployed validated revisions.

**Files Created/Modified**:
- `backend/api/src/app.py` - ensured Firebase Admin initialization before token verification; canonicalized UID by verified email alias; returned profile completion metadata in bootstrap.
- `backend/agent_logs/IDENTITY_CANONICALIZATION_PROFILE_COMPLETION_20260221.md` - backend implementation record.

### 2. App routing and onboarding profile persistence fixes

Aligned app-side routing with backend completion contract and made onboarding progression wait on successful profile sync writes.

**Files Created/Modified**:
- `Unstoppable/WelcomeView.swift` - guarded post-sign-in routing on successful bootstrap, preserved explicit user-facing failure message.
- `Unstoppable/Networking/APIClient.swift` - debug auth mode traces (`auth=none|dev_user_id|bearer`).
- `Unstoppable/NicknameView.swift` - await profile save before continue.
- `Unstoppable/onboarding/AgeGroupView.swift` - await profile save before continue.
- `Unstoppable/onboarding/GenderSelectionView.swift` - await profile save before continue.
- `Unstoppable/onboarding/NotificationPermissionView.swift` - await profile save before continue.
- `Unstoppable/onboarding/TermsSheetView.swift` - await profile save before dismiss.
- `Unstoppable/onboarding/PaywallView.swift` - await profile save before home navigation.
- `Unstoppable.xcodeproj/project.pbxproj` - Debug `API_USE_DEV_AUTH = NO` for Firebase Bearer testing.

### 3. Reset tooling for deterministic onboarding retests

Added scripts to reset user profile or full onboarding state without deleting identity alias data.

**Files Created/Modified**:
- `backend/api/scripts/reset_user_profile.py` - delete `users/{uid}/profile/self` by email or UID.
- `backend/api/scripts/reset_user_onboarding.py` - clear onboarding-related subcollections (`profile`, `routine`, `progress`, `stats`, `payments`).
- `backend/api/pyproject.toml` - added Poetry project metadata (`python ^3.12`, Flask/gunicorn/firebase-admin dependencies).
- `backend/api/README.md` - documented reset script usage and Poetry setup.

### 4. New runbook for API/app auth troubleshooting

Authored a dedicated runbook that captures real failure modes, command-based diagnostics, and retest procedures.

**Files Created/Modified**:
- NEW: `backend/api/API_RUNBOOK.md` - backend + app troubleshooting guide for auth/bootstrap/profile sync incidents.

---

## Key Results

- Eliminated partial sign-in state where auth succeeded but bootstrap failed silently for routing.
- Confirmed canonical identity merge behavior for verified same-email providers at backend model level.
- Added repeatable operator workflow to reset user data and revalidate onboarding end to end.
- Captured concrete troubleshooting workflow in one API/auth runbook for future incidents.

| Metric | Before | After |
|--------|--------|-------|
| Post-sign-in bootstrap reliability | Intermittent failures surfaced as generic app error | Stable with corrected backend auth/deploy + app guards |
| Onboarding write observability | Weak (flow could advance without reliable persistence) | Stronger (awaited writes + inline sync failures) |
| Re-test readiness after account state drift | Manual and error-prone | Scripted profile and onboarding reset paths |

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Keep profile completion truth in backend bootstrap | Prevents duplicated completion logic and drift between app/backend. |
| Show explicit app error when sign-in succeeds but bootstrap fails | Avoids false-positive navigation to onboarding/home on stale state. |
| Use canonical UID aliasing only for verified-email identities | Prevents unsafe merges from unverified provider claims. |
| Add reset scripts instead of manual console edits | Makes retests fast, repeatable, and less error-prone. |

---

## Verification

```bash
python3 -m py_compile backend/api/src/app.py
backend/api/deploy_cloud_run.sh unstoppable-app-dev
ALLOW_UNAUTHENTICATED=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev
ALLOW_UNAUTHENTICATED=1 ALLOW_DEV_USER_HEADER=0 backend/api/deploy_cloud_run.sh unstoppable-app-dev
gcloud run services describe unstoppable-api --project unstoppable-app-dev --region us-central1 --format='yaml(status.latestReadyRevisionName,status.latestCreatedRevisionName,status.traffic,status.url)'
gcloud run services proxy unstoppable-api --project unstoppable-app-dev --region us-central1 --port 8081
curl -sS -i --max-time 20 http://127.0.0.1:8081/healthz
curl -sS -i --max-time 20 -H 'X-User-Id: dev-profile-check-20260221' http://127.0.0.1:8081/v1/bootstrap
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
```

- [x] Backend deploy + revision/traffic checks succeeded.
- [x] Proxy/API smoke checks succeeded.
- [x] App build and simulator launch checks succeeded.
- [x] Profile reset executed for canonical test identity and verified removed state.
- [x] User reported Google/Apple sign-in flow now working.

---

## Key Learnings

1. **Service auth and app auth are separate controls**: Cloud Run IAM-level auth can block requests before Flask/Firebase token verification is reached.
2. **Bootstrap is the routing choke point**: App sign-in success alone is insufficient; routing must depend on successful bootstrap retrieval.
3. **Reset tooling is essential for auth/onboarding QA**: Existing Firestore profile data can hide regressions in onboarding/profile completion behavior.

---

## Related Documents

- `backend/agent_logs/IDENTITY_CANONICALIZATION_PROFILE_COMPLETION_20260221.md` - canonical identity and profile completion backend implementation.
- `Unstoppable/agent_logs/PROFILE_COMPLETION_ROUTING_20260221.md` - app-side profile completion routing update.
- `agent_logs/APPLE_AUTH_FIREBASE_ROLLOUT_20260221.md` - Apple auth rollout baseline and pending matrix.
