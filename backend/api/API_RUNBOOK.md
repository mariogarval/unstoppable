# Unstoppable API/Auth Troubleshooting Runbook

**Last Updated**: 2026-02-21  
**Scope**: Backend API auth + app auth/bootstrap/profile-sync integration  
**Projects**: `backend/api` and `Unstoppable`

---

## 1) System Contract (What Must Be True)

1. iOS app signs in with Firebase (Google or Apple) and sends `Authorization: Bearer <Firebase ID token>` to backend.
2. Backend verifies Firebase token and resolves canonical user ID:
   - Email-verified identities map through `user_email_aliases/{lowercase_email}`.
   - UID aliases map through `user_uid_aliases/{uid}`.
3. User profile data is stored at:
   - `users/{canonical_uid}/profile/self`
4. Onboarding completion is determined by backend-required fields and returned via `GET /v1/bootstrap`:
   - `isProfileComplete`
   - `profileCompletion.isComplete`
   - `profileCompletion.missingRequiredFields`

If any of the above fails, the app may sign in successfully but fail to route correctly.

---

## 2) Primary Symptom Map

| Symptom | Likely Layer | Most Likely Cause |
|---|---|---|
| `Signed in, but failed to load your account. Please try again.` | App -> Backend bootstrap | `/v1/bootstrap` failed after sign-in (401/403/5xx/network) |
| Google/Apple same email does not behave as one user | Backend identity canonicalization | Alias mapping missing or request not using Bearer token |
| Onboarding screens show, but Firestore profile does not update | App profile sync + API auth | `syncUserProfile` calls failing (auth/mode/deploy) or not awaited in flow |
| App works with dev header but fails with real sign-in | Runtime auth mode mismatch | App using `X-User-Id` flow while backend expects Bearer, or vice versa |
| Everything worked before reset, now fails | Data reset + flow assumptions | Profile removed but API auth/bootstrap path still broken |

---

## 3) Incidents Resolved In This Rollout

## A. Cloud Run ingress auth blocked app traffic

- **Observed behavior**: App sign-in completed, but bootstrap failed and app showed:
  - `Signed in, but failed to load your account. Please try again.`
- **Root cause**: Cloud Run service-level auth was rejecting unauthenticated invocation before app-level Firebase token logic could run.
- **Fix applied**: Redeployed backend with unauthenticated ingress for this app flow.

```bash
ALLOW_UNAUTHENTICATED=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev
```

---

## B. Firebase token verification called before Firebase Admin init

- **Observed risk**: Bearer-token verification path can fail if Firebase Admin app is not initialized.
- **Fix applied**: Added explicit initialization before token verify in `backend/api/src/app.py`.
  - `_ensure_firebase_initialized()` now runs before `auth.verify_id_token(token)`.

---

## C. Onboarding progress not reliably persisted

- **Observed behavior**: User progressed through onboarding UI, but expected profile fields did not appear in Firestore.
- **Root cause**: Flow advanced without consistently enforcing successful profile sync.
- **Fix applied**: Onboarding screens now await `syncUserProfile` and block navigation on failure with inline errors.
  - `Unstoppable/NicknameView.swift`
  - `Unstoppable/onboarding/AgeGroupView.swift`
  - `Unstoppable/onboarding/GenderSelectionView.swift`
  - `Unstoppable/onboarding/NotificationPermissionView.swift`
  - `Unstoppable/onboarding/TermsSheetView.swift`
  - `Unstoppable/onboarding/PaywallView.swift`

---

## D. Profile completion re-test confusion after previous data existed

- **Observed behavior**: Routing looked partially correct because old profile data already existed.
- **Resolution**: Added reset scripts for deterministic re-tests.
  - `backend/api/scripts/check_user_payments.py`
  - `backend/api/scripts/reset_user_profile.py`
  - `backend/api/scripts/reset_user_payments.py`
  - `backend/api/scripts/reset_user_onboarding.py`

---

## 4) Critical Files and Responsibilities

- `backend/api/src/app.py`
  - Bearer token verification (`auth.verify_id_token`)
  - Canonical user resolution (`user_email_aliases`, `user_uid_aliases`)
  - Profile completion computation (`_profile_completion`)
  - Bootstrap response contract
- `Unstoppable/Networking/APIClient.swift`
  - Runtime auth mode selection and headers
  - DEBUG log line: `APIClient <METHOD> <PATH> auth=<mode>`
- `Unstoppable/WelcomeView.swift`
  - Post-sign-in bootstrap fetch
  - Error message shown when bootstrap fetch fails
  - Routing by completion state

---

## 5) Fast Triage Checklist

Run in this order.

1. Confirm backend URL and Cloud Run status.
```bash
gcloud run services describe unstoppable-api \
  --project unstoppable-app-dev \
  --region us-central1 \
  --format='yaml(status.latestReadyRevisionName,status.latestCreatedRevisionName,status.traffic,status.url)'
```

2. Confirm API health endpoint.
```bash
curl -sS -i --max-time 20 https://unstoppable-api-1094359674860.us-central1.run.app/healthz
```

3. Confirm app is using Bearer mode (not dev header) in DEBUG logs.
   - Look for: `APIClient GET /v1/bootstrap auth=bearer`
   - If you see `auth=dev_user_id`, app config is wrong for Firebase sign-in testing.

4. Check backend logs during a failing sign-in/bootstrapping attempt.
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="unstoppable-api"' \
  --project unstoppable-app-dev \
  --limit 100 \
  --freshness=30m \
  --format='value(timestamp,severity,textPayload,jsonPayload.message,httpRequest.status)'
```

5. Validate bootstrap/profile using local Cloud Run proxy if direct debugging is needed.
```bash
gcloud run services proxy unstoppable-api \
  --project unstoppable-app-dev \
  --region us-central1 \
  --port 8081
```

Then test:
```bash
curl -sS -i --max-time 20 http://127.0.0.1:8081/healthz
```

For local-dev header mode only (must deploy with `ALLOW_DEV_USER_HEADER=1`):
```bash
curl -sS -i --max-time 20 \
  -H 'X-User-Id: dev-profile-check-20260221' \
  http://127.0.0.1:8081/v1/bootstrap
```

---

## 6) Auth Mode Matrix (App + Backend)

| Scenario | App auth mode | Required backend setting | Header sent |
|---|---|---|---|
| Real Google/Apple sign-in | `bearerTokenProvider` | Firebase Admin + Bearer verification path | `Authorization: Bearer <ID token>` |
| Local no-auth testing | `devUserID` | `ALLOW_DEV_USER_HEADER=1` | `X-User-Id: <id>` |

Current debug build expectation for real auth tests:
- `Unstoppable.xcodeproj/project.pbxproj` has `API_USE_DEV_AUTH = NO` in Debug.

---

## 7) Profile Completion Contract

Backend-required fields:
- `nickname` (non-empty string)
- `notificationsEnabled` (boolean)
- `termsAccepted` (`true`)
- `termsOver16Accepted` (`true`)
- `paymentOption` (non-empty string)

`paymentOption` is typically written by paywall profile sync, and is now also backfilled by payment snapshot/webhook sync when inferred from product metadata.

If any are missing, backend returns:
- `isProfileComplete = false`
- `profileCompletion.missingRequiredFields = [...]`

App routing in `WelcomeView`:
- complete -> `HomeView`
- incomplete -> onboarding flow (`NicknameView`)

---

## 8) Reset and Re-Test Procedures

Set project:
```bash
export GOOGLE_CLOUD_PROJECT=unstoppable-app-dev
```

Inspect payment/subscription state and RevenueCat webhook events:
```bash
cd backend/api
python scripts/check_user_payments.py --email your-email@example.com
```

Reset profile only:
```bash
cd backend/api
python scripts/reset_user_profile.py --email your-email@example.com
```

Reset payment status (`users/{uid}/payments/*`) and clear `users/{uid}/profile/self.paymentOption`:
```bash
cd backend/api
python scripts/reset_user_payments.py --email your-email@example.com
```

Optional: also clear RevenueCat webhook event docs for that user:
```bash
python scripts/reset_user_payments.py --email your-email@example.com --clear-webhook-events
```

Reset full onboarding data (`profile`, `routine`, `progress`, `stats`, `payments`):
```bash
cd backend/api
python scripts/reset_user_onboarding.py --email your-email@example.com
```

Dry run:
```bash
python scripts/reset_user_profile.py --email your-email@example.com --dry-run
python scripts/reset_user_payments.py --email your-email@example.com --dry-run
python scripts/reset_user_onboarding.py --email your-email@example.com --dry-run
```

Recommended verification after reset:
1. Sign in with Google and complete onboarding.
2. Sign out.
3. Sign in with Apple using the same verified email.
4. Confirm same canonical user data is returned in bootstrap and no duplicate profile tree is created.

---

## 9) Deploy/Runtime Commands Used During This Rollout

Deploy:
```bash
backend/api/deploy_cloud_run.sh unstoppable-app-dev
ALLOW_UNAUTHENTICATED=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev
ALLOW_UNAUTHENTICATED=1 ALLOW_DEV_USER_HEADER=0 backend/api/deploy_cloud_run.sh unstoppable-app-dev
```

Python sanity:
```bash
python3 -m py_compile backend/api/src/app.py
```

iOS build:
```bash
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj \
  -scheme Unstoppable \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
```

---

## 10) Known Good End State

You are in a healthy state when all are true:

1. `GET /healthz` returns `200`.
2. App DEBUG logs show `auth=bearer` for protected API calls.
3. Post sign-in `GET /v1/bootstrap` succeeds and no fallback error message appears.
4. Profile writes are visible at `users/{canonical_uid}/profile/self`.
5. Same-email Google and Apple logins resolve to one canonical user profile.
