# Unstoppable iOS App + Backend Sync (Current State)

This project is a SwiftUI iOS app with local-first state, Firebase + Apple/Google sign-in, and background sync to a Python API on Google Cloud Run.

## Runbooks

- API/Auth troubleshooting: `backend/api/API_RUNBOOK.md`

## Current Backend Status

- GCP project: `unstoppable-app-dev`
- API service: `unstoppable-api` (Cloud Run, Python/Flask)
- Base URL (dev): `https://unstoppable-api-1094359674860.us-central1.run.app`
- Database: Firestore (Native mode, `us-central1`)

## Current Auth Status (Apple/Google + Firebase)

- App supports `Continue with Apple` and `Continue with Google` from `Unstoppable/WelcomeView.swift`.
- Firebase is initialized at startup in `Unstoppable/UnstoppableApp.swift`.
- Auth/session management lives in `Unstoppable/Auth/AuthSessionManager.swift`.
- Current iOS bundle ID is `app.unstoppable.unstoppable`.
- On launch, app attempts session restore from `FirebaseAuth.currentUser` and reconfigures API auth mode.
- On successful Apple/Google sign-in, API auth switches to `Authorization: Bearer <Firebase ID token>` via `bearerTokenProvider`.
- Account-link behavior is email-based: if Apple collides with an existing Google account, users are prompted to sign in with Google first and then link Apple.
- Backend canonicalizes authenticated users by verified token email so Google/Apple sign-ins with the same email write to the same Firestore user record.
- Post-auth routing uses backend profile completion (`isProfileComplete`) so users with incomplete profile data are sent through onboarding instead of landing in `HomeView`.
- Settings includes a functional `Sign Out` action in `Unstoppable/HomeView.swift` and routes back to `WelcomeView`.
- If bundle ID changes, regenerate Firebase iOS config (`GoogleService-Info.plist`) for the new app and re-check `CFBundleURLSchemes` (Google reversed client ID) in `Unstoppable/Info.plist`.

## Current Payments Status (RevenueCat, Phase 1)

- RevenueCat SDK is linked via SPM (`https://github.com/RevenueCat/purchases-ios`) and initialized at app launch in `Unstoppable/UnstoppableApp.swift`.
- Runtime payments orchestration is centralized in `Unstoppable/Payments/RevenueCatManager.swift`.
- RevenueCat API key is loaded from local xcconfig (not committed):
  - Base config: `Unstoppable/Config/RevenueCat.xcconfig`
  - Local override (gitignored): `Unstoppable/Config/Secrets.local.xcconfig`
  - Example template: `Unstoppable/Config/Secrets.local.xcconfig.example`
- Auth identity is mapped to RevenueCat user identity:
  - On restore/sign-in: `Purchases.logIn(firebaseUID)`
  - On sign-out: `Purchases.logOut()`
- `Unstoppable/onboarding/PaywallView.swift` now:
  - loads live offerings from RevenueCat when available
  - supports purchase + restore actions
  - keeps static plan cards as visual fallback, but primary CTA now retries offerings refresh instead of silently proceeding without a purchase package
- Local purchase UX testing is available via StoreKit configuration:
  - file: `Unstoppable/StoreKit/UnstoppableLocal.storekit`
  - scheme wiring: `Unstoppable.xcodeproj/xcshareddata/xcschemes/Unstoppable.xcscheme`
  - to use it, run the app from Xcode with the `Unstoppable` scheme (the scheme launch action loads the local StoreKit file)
- Optional Settings test entry for paywall:
  - feature flag key: `REVENUECAT_SHOW_SETTINGS_PAYWALL_TEST_BUTTON`
  - default: `NO`
  - set to `YES` in `Unstoppable/Config/Secrets.local.xcconfig` to show `Open Paywall (Test)` button in Settings.
- Current paywall selection sync still posts `paymentOption` through `POST /v1/user/profile`.
- RevenueCat customer-info updates can sync subscription snapshot data to backend via `POST /v1/payments/subscription/snapshot` when `REVENUECAT_ENABLE_BACKEND_SYNC=YES` (default `NO` keeps payments app-side only).

## App Flow and Endpoint Calls

Entry point:
- `Unstoppable/UnstoppableApp.swift` -> `WelcomeView`

Primary navigation chain:
1. `WelcomeView`
2. `NicknameView`
3. `AgeGroupView`
4. `GenderSelectionView`
5. `NotificationPermissionView`
6. `BeforeAfterView`
7. `TermsSheetView` (modal)
8. `PaywallView`
9. `HomeView`

Connected endpoint calls in the app:
- `GET /v1/bootstrap`
  - Called once on app start from `Unstoppable/WelcomeView.swift` (`bootstrapIfNeeded`).
- `POST /v1/user/profile`
  - Called incrementally during onboarding:
    - `Unstoppable/NicknameView.swift`
    - `Unstoppable/onboarding/AgeGroupView.swift`
    - `Unstoppable/onboarding/GenderSelectionView.swift`
    - `Unstoppable/onboarding/NotificationPermissionView.swift`
    - `Unstoppable/onboarding/TermsSheetView.swift`
    - `Unstoppable/onboarding/PaywallView.swift` (records selected payment option)
- `PUT /v1/routines/current`
  - Called from `Unstoppable/HomeView.swift` (`syncRoutineSnapshot`) after routine mutations:
    - template apply
    - task toggle
    - add/delete task
    - routine time change
    - timer completion
    - initial appear sync
- `POST /v1/progress/daily`
  - Called from `Unstoppable/StreakManager.swift` (`syncTodayProgress`) whenever daily progress changes.
- `POST /v1/payments/subscription/snapshot`
  - Called from `Unstoppable/Payments/RevenueCatManager.swift` after RevenueCat customer-info updates (purchase/restore/login/refresh).

## Networking Layer

Core files:
- `Unstoppable/Networking/APIClient.swift`
- `Unstoppable/Networking/Models.swift`
- `Unstoppable/Sync/UserDataSyncService.swift`

`APIClient` supports:
- `GET`, `POST`, `PUT`
- shared JSON encode/decode
- auth modes:
  - `.none`
  - `.devUserID("...")` via `X-User-Id` header
  - `.bearerTokenProvider` via `Authorization: Bearer ...`

Build-time config keys (in project build settings / Info.plist injection):
- `API_BASE_URL`
- `API_USE_DEV_AUTH`
- `API_DEV_USER_ID`
- `REVENUECAT_IOS_API_KEY`
- `REVENUECAT_ENABLE_BACKEND_SYNC` (`NO` default, set `YES` to enable backend snapshot sync)

Current defaults:
- Debug: supports dev auth (`X-User-Id`, default `dev-user-001`) and switches to bearer token auth after Apple/Google sign-in.
- Release: points to `https://api.unstoppable.app` with dev auth disabled.

## Data Model and Sync Behavior

Local state still drives UI first:
- Streak/progress persisted locally in `UserDefaults` via `StreakManager`.
- Routine/task UI state managed in `HomeView`.

Sync behavior:
- API calls are fire-and-forget background `Task` calls.
- Local writes happen first; failed sync currently logs debug messages.
- No retry queue/offline reconciliation yet.

## Backend Endpoint Contract (Current)

- `POST /v1/user/profile`
  - Accepts partial profile fields:
    - `nickname`, `ageGroup`, `gender`, `notificationsEnabled`
    - `termsAccepted`, `termsOver16Accepted`, `termsMarketingAccepted`
    - `paymentOption` (`annual`, `monthly`, `skip`, `dismiss`)
- `PUT /v1/routines/current`
  - Accepts `routineTime` (`HH:mm`) and full task snapshot.
- `POST /v1/progress/daily`
  - Accepts `date` (`yyyy-MM-dd`), `completed`, `total`, `completedTaskIds`.
- `GET /v1/bootstrap`
  - Returns: `userId`, `profile`, `isProfileComplete`, `profileCompletion`, `routine`, `streak`, `progress.today`, and `subscription`.
- `GET /v1/user/subscription`
  - Returns latest normalized subscription snapshot for current authenticated user.
- `POST /v1/payments/subscription/snapshot`
  - Accepts app-reported subscription snapshot (entitlement/product/state fields) for support/debug surfaces.
- `POST /v1/payments/revenuecat/webhook`
  - RevenueCat webhook endpoint (Bearer shared secret) with event idempotency and out-of-order protection.

## Simulator Testing

Launch:

```bash
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

Stream app logs:

```bash
xcrun simctl spawn booted log stream --level debug --predicate 'process == "Unstoppable"'
```

Debug failure logs to watch:
- `bootstrap failed: ...`
- `syncUserProfile(...) failed: ...`
- `syncCurrentRoutine failed: ...`
- `syncDailyProgress failed: ...`
- `apple sign-in failed: ...`
- `google sign-in failed: ...`
- `RevenueCat offerings load failed: ...`
- `RevenueCat purchase failed: ...`
- `RevenueCat restore failed: ...`

## Local Shell Output Logs (Reusable)

Use `_shell_output/` at repo root for local-only execution logs (not committed).

Initialize logging helpers:

```bash
source /Users/luisgalvez/.codex/skills/persistent_shell_output/scripts/persistent_shell_output.sh
```

Log command steps and manual actions:

```bash
shell_step GA-00 git status --short
shell_note "[GA-11] Enabled Google provider in Firebase Console"
```

Current local log examples:
- `_shell_output/SHELL_OUTPUT_SESSION_20260212_222218_pid84179.log`
