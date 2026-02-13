# RevenueCat Backend Phase 3 - 2026-02-12

## WHAT was done
- Implemented RevenueCat backend webhook ingestion route with shared-secret auth:
  - `POST /v1/payments/revenuecat/webhook`
- Added webhook idempotency using event-document `create()` semantics to ignore duplicate deliveries by `eventId`.
- Added out-of-order protection by comparing incoming `latestEventAt` with stored subscription event timestamp.
- Added normalized subscription persistence under Firestore:
  - `users/{appUserId}/payments/subscription`
- Extended bootstrap response to include subscription snapshot:
  - `GET /v1/bootstrap` now returns `subscription`.
- Added app-facing subscription endpoints:
  - `GET /v1/user/subscription`
  - `POST /v1/payments/subscription/snapshot`
- Updated backend README with new endpoints and `REVENUECAT_WEBHOOK_AUTH` configuration.

## KEY FILES modified
- `/Users/luisgalvez/Projects/unstoppable/backend/api/src/app.py`
- `/Users/luisgalvez/Projects/unstoppable/backend/api/README.md`

## STATUS
- Backend payment webhook and subscription persistence logic is implemented locally.
- Python syntax validation passed for `backend/api/src/app.py`.
- Live endpoint execution tests were not run in this session because local `firebase-admin` runtime dependencies were not installed in the current shell environment.

## KEY DECISIONS made
- Keep subscription data in `users/{appUserId}/payments/subscription` to align bootstrap hydration with user-centric reads.
- Require webhook auth header `Authorization: Bearer <REVENUECAT_WEBHOOK_AUTH>` and reject unauthorized calls.
- Use Firestore event documents for idempotency before subscription mutation.
- Treat older events as out-of-order and skip subscription state overwrite.

## EXECUTED COMMANDS (with CLI args)
- `python3 -m py_compile backend/api/src/app.py`
- `rg -n "@app\.(get|post|put)\(\"/v1/(payments|user/subscription|bootstrap)" backend/api/src/app.py`
- `rg -n "REVENUECAT_WEBHOOK_AUTH|/v1/payments/revenuecat/webhook|/v1/payments/subscription/snapshot|/v1/user/subscription" backend/api/README.md`
- `xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build`
- `./scripts/run_ios_sim.sh "iPhone 17 Pro"`
