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

## Practical Implementation Plan in This Codebase

1. Create a small API layer:
   - `Unstoppable/Networking/APIClient.swift`
   - `Unstoppable/Networking/Models/*.swift`
2. Add a sync coordinator:
   - `Unstoppable/Sync/UserDataSyncService.swift`
3. Inject service where mutations happen:
   - onboarding views + `HomeView` + `StreakManager`
4. Keep local updates immediate, sync async:
   - update UI/local state first
   - fire network request after (retry on failure)
5. Add a bootstrap on app launch:
   - in `UnstoppableApp` or `WelcomeView` on appear, fetch `/v1/bootstrap` and hydrate local stores.
6. Add auth token plumbing:
   - attach Firebase/Auth ID token as `Authorization: Bearer <token>` in `APIClient`.
7. Deploy v1 backend on Google Cloud:
   - create Firestore database
   - deploy Cloud Run service with the 4 endpoints
   - configure CORS/auth validation if needed
8. Add reliability guardrails:
   - queue failed writes locally and retry with exponential backoff
   - make `POST /v1/progress/daily` idempotent per `(userId, date)`

## Suggested Rollout Order (Google Cloud)

1. Ship `POST /v1/progress/daily` first (hook from `StreakManager.updateToday(totalTasks:)`).
2. Ship `GET /v1/bootstrap` second (restore state on launch).
3. Ship `PUT /v1/routines/current` for task/routine persistence.
4. Ship `POST /v1/user/profile` for onboarding/profile completion.

## Most Important First Integration Point

If you only do one change first, start in `StreakManager.updateToday(totalTasks:)`.

Reason: nearly all meaningful user progress converges there, so one endpoint call from that method can capture daily completion + streak behavior without rewriting all views first.
