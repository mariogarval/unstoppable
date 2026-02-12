# Backend Implementation Plan

## Recommended Google Cloud Stack

Primary recommendation:
- `Cloud Run` for the REST API (Python service with Flask).
- `Firestore (Native mode)` for user profile, routine, and daily progress documents.

Supporting services:
- `Firebase Authentication` (or `Identity Platform`) for Apple/Google auth tokens from iOS.
- `Secret Manager` for API secrets/config.
- `Cloud Tasks` for retryable async jobs (optional for non-blocking sync).
- `Cloud Logging` + `Cloud Monitoring` for observability.

Why this stack:
- You keep full control of endpoint design (`/v1/user/profile`, etc.) while staying serverless.
- It scales automatically and is simple to operate for an iOS app at this stage.
- Firestore matches your current document-like data model (profile, routine, daily snapshot).

## Endpoint-to-Service Mapping

- `POST /v1/user/profile`
  - Cloud Run handler writes to `users/{userId}/profile` in Firestore.
- `PUT /v1/routines/current`
  - Cloud Run handler writes to `users/{userId}/routine/current`.
- `POST /v1/progress/daily`
  - Cloud Run handler upserts `users/{userId}/progress/{yyyy-MM-dd}`.
- `GET /v1/bootstrap`
  - Cloud Run handler reads profile + routine + latest streak/progress docs and returns one payload.

## Current Backend Deployment

- GCP project: `unstoppable-app-dev`
- Cloud Run service: `unstoppable-api`
- Base URL: `https://unstoppable-api-qri3urt3ha-uc.a.run.app`
- Firestore: Native mode in `us-central1`

## App Integration Plan (Start Using Endpoints Now)

1. Add app networking layer (new files):
   - `Unstoppable/Networking/APIClient.swift`
   - `Unstoppable/Networking/Models.swift`
   - `Unstoppable/Sync/UserDataSyncService.swift`
2. Configure endpoint base URL in app:
   - store base URL in a single config constant (do not hardcode across views).
3. Wire `POST /v1/progress/daily` first:
   - call from `StreakManager.updateToday(totalTasks:)` after local state is updated.
4. Wire `GET /v1/bootstrap` at launch:
   - call in `UnstoppableApp`/`WelcomeView` on startup and hydrate local app state before user starts routine flow.
5. Wire routine sync:
   - call `PUT /v1/routines/current` from `HomeView` when template is applied, task is added/deleted, or routine time is changed.
6. Wire profile/onboarding sync:
   - call `POST /v1/user/profile` from onboarding transitions (nickname/age/gender/notifications/terms).
7. Keep app responsive:
   - local state updates first, network sync in background, queue/retry on failures.
8. Move from dev auth to production auth:
   - replace `X-User-Id` dev header flow with `Authorization: Bearer <Firebase ID token>`.

## Suggested Rollout Order (Google Cloud)

1. Ship `POST /v1/progress/daily` first (hook from `StreakManager.updateToday(totalTasks:)`).
2. Ship `GET /v1/bootstrap` second (restore state on launch).
3. Ship `PUT /v1/routines/current` for task/routine persistence.
4. Ship `POST /v1/user/profile` for onboarding/profile completion.

## Most Important First Integration Point

If you only do one change first, start in `StreakManager.updateToday(totalTasks:)`.

Reason: nearly all meaningful user progress converges there, so one endpoint call from that method can capture daily completion + streak behavior without rewriting all views first.

## Endpoint Call Map (App -> Backend)

- `StreakManager.updateToday(totalTasks:)` -> `POST /v1/progress/daily`
- App startup (`UnstoppableApp` or `WelcomeView.onAppear`) -> `GET /v1/bootstrap`
- `HomeView` task/routine mutations -> `PUT /v1/routines/current`
- Onboarding completion points -> `POST /v1/user/profile`
