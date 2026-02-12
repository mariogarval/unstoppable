# Unstoppable iOS App + Backend Sync (Current State)

This project is a SwiftUI iOS app with local-first state and background sync to a Python API on Google Cloud Run.

## Current Backend Status

- GCP project: `unstoppable-app-dev`
- API service: `unstoppable-api` (Cloud Run, Python/Flask)
- Base URL (dev): `https://unstoppable-api-1094359674860.us-central1.run.app`
- Database: Firestore (Native mode, `us-central1`)

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

Current defaults:
- Debug: uses dev auth (`X-User-Id`, default `dev-user-001`) against Cloud Run dev URL.
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
  - Returns: `userId`, `profile`, `routine`, `streak`, and `progress.today`.

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
