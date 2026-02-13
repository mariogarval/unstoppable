# RevenueCat Payments Implementation Plan (Reusable Runbook)

Last updated: 2026-02-13  
Owner: `Unstoppable` app team  
Status: Planned

## Purpose
Add production-grade subscription payments using RevenueCat, with iOS app integration, backend entitlement sync, and an execution model that can be reused in other projects.

## Outcomes
- Users can see plans, purchase, restore purchases, and keep access in sync across app launches/devices.
- Entitlement state is deterministic and available in both app and backend.
- Sign-in/sign-out flows correctly map to RevenueCat user identity (`appUserID`).
- Rollout can be staged safely with validation gates and rollback steps.
- All actions are logged using step IDs so this runbook can be repeated in future repos.

## Current Implementation Status (Unstoppable)
- Phase 1 (Store + RevenueCat dashboard): pending manual dashboard setup/verification.
- Phase 2 (iOS integration): implemented in app, builds and launches successfully.
- Phase 3 (Backend webhook + subscription state): implemented locally in `backend/api/src/app.py`; deploy/runtime verification pending.
- Phase 4+ (QA, rollout, rollback drills): pending.

## Scope
- In scope:
  - RevenueCat project setup (products, entitlements, offerings).
  - iOS SDK integration in `Unstoppable`.
  - Backend webhook ingestion and subscription status persistence.
  - QA matrix for sandbox and release testing.
- Out of scope (for this phase):
  - Custom pricing experiments beyond configured RevenueCat offerings.
  - Web checkout flows.
  - One-time consumables.

## Architecture Decisions
1. RevenueCat is the payment orchestration layer and subscription event source.
2. App auth identity (`Firebase UID`) is the canonical `appUserID` for RevenueCat.
3. Premium access checks are entitlement-based (`premium` entitlement), not SKU-based.
4. Backend stores a normalized subscription snapshot for business logic and support tooling.
5. Webhook handling must be idempotent and event-order safe.

## Reusable Inputs (Set Before Execution)
Replace these values per project.

```bash
export APP_NAME="Unstoppable"
export IOS_BUNDLE_ID="com.unstoppable.app"
export XCODE_PROJECT_PATH="/Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj"
export XCODE_SCHEME="Unstoppable"
export SIMULATOR_NAME="iPhone 17 Pro"
export FIREBASE_PROJECT_ID="unstoppable-app-dev"
export API_BASE_URL_DEV="https://unstoppable-api-1094359674860.us-central1.run.app"

export RC_PROJECT_NAME="unstoppable"
export RC_WEBHOOK_AUTH="<strong_random_webhook_secret>"
export RC_ENTITLEMENT_ID="premium"
export RC_OFFERING_ID="default"
```

## Secret Management Standard (Do Not Commit)
Use this pattern in every iOS project to prevent accidental key exposure.

1. iOS key injection via local xcconfig files:
- Commit `App/Config/RevenueCat.xcconfig` with an empty default:
  - `REVENUECAT_IOS_API_KEY =`
  - `#include? "Secrets.local.xcconfig"`
- Commit `App/Config/Secrets.local.xcconfig.example` with placeholders only.
- Add `App/Config/Secrets.local.xcconfig` to `.gitignore`.
- Set app target `Debug/Release` `baseConfigurationReference` to `RevenueCat.xcconfig`.
- Inject `REVENUECAT_IOS_API_KEY` into `Info.plist` as `$(REVENUECAT_IOS_API_KEY)`.

2. Backend/webhook secret storage:
- Local dev: `.env.local` (gitignored).
- CI/CD and production: secret manager (for GCP, use Secret Manager and environment variable injection in Cloud Run).

3. Rotation and hygiene:
- Keep separate keys for test/dev/prod projects.
- Rotate keys immediately if they are posted in public channels or committed.
- Never place secrets directly in tracked files, PR descriptions, or command logs.

## Execution Logging Standard
Use repository-local action logs during rollout.

```bash
source /Users/luisgalvez/.codex/skills/actions-log-local/scripts/actions_log.sh
action_step RC-00 git status --short
action_note "[RC-11] Enabled products in App Store Connect and mapped in RevenueCat"
```

Rules:
- Use `action_step RC-XX ...` for each meaningful command.
- Use `action_note` for every manual console action (App Store Connect, RevenueCat dashboard, Firebase console, etc.).
- Keep logs in `_actions_log/` and do not commit them.

## Phase Plan (With Step IDs)

## Phase 0: Baseline and Branch

### RC-00: Capture repo baseline
```bash
action_step RC-00 git -C /Users/luisgalvez/Projects/unstoppable status --short
action_step RC-00A git -C /Users/luisgalvez/Projects/unstoppable branch --show-current
```
Acceptance:
- Current state and starting branch logged.

### RC-01: Create working branch
```bash
action_step RC-01 git -C /Users/luisgalvez/Projects/unstoppable checkout -b codex/revenuecat-payments
```
Acceptance:
- New branch created and active.

### RC-02: Baseline build before payment changes
```bash
action_step RC-02 xcodebuild -project "$XCODE_PROJECT_PATH" -scheme "$XCODE_SCHEME" -configuration Debug -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" build
```
Acceptance:
- Baseline build succeeds.

## Phase 1: Store + RevenueCat Configuration

### RC-10: Create store products
Manual actions:
- App Store Connect: create auto-renewable subscriptions (example: monthly, annual).
- Define group, durations, localized names/descriptions, and trial policy.

Log example:
```bash
action_note "[RC-10] Created iOS subscriptions (monthly, annual) in App Store Connect subscription group Premium"
```
Acceptance:
- Products are in a testable state for Sandbox/TestFlight.

### RC-11: Create RevenueCat project/app and connect store
Manual actions:
- RevenueCat dashboard: create project and iOS app (`$IOS_BUNDLE_ID`).
- Connect App Store credentials.
- Copy iOS public SDK key.

Log example:
```bash
action_note "[RC-11] RevenueCat project/app created and App Store connected; iOS SDK key stored in secrets"
```
Acceptance:
- RevenueCat can read products from connected store.

### RC-12: Configure entitlement and offerings
Manual actions:
- Create entitlement: `premium`.
- Create offering: `default`.
- Add packages:
  - `$rc_monthly`
  - `$rc_annual`
- Map store products to packages.

Log example:
```bash
action_note "[RC-12] Configured entitlement premium and default offering with monthly/annual packages"
```
Acceptance:
- RevenueCat offering resolves with expected packages.

### RC-13: Configure webhook target
Manual actions:
- RevenueCat -> Integrations -> Webhooks.
- Endpoint: `<API_BASE_URL>/v1/payments/revenuecat/webhook`
- Authorization header: `Bearer $RC_WEBHOOK_AUTH`

Log example:
```bash
action_note "[RC-13] Added RevenueCat webhook endpoint and auth header"
```
Acceptance:
- Test webhook delivers successfully (2xx).

## Phase 2: iOS App Integration (`Unstoppable`)

Target files (expected):
- `Unstoppable/UnstoppableApp.swift`
- `Unstoppable/Auth/AuthSessionManager.swift`
- `Unstoppable/onboarding/PaywallView.swift`
- `Unstoppable/Networking/APIClient.swift`
- New: `Unstoppable/Payments/RevenueCatManager.swift`

### RC-20: Add RevenueCat SDK dependency
Preferred SPM URL:
- `https://github.com/RevenueCat/purchases-ios`

Log example:
```bash
action_note "[RC-20] Added purchases-ios package to Unstoppable target"
```
Acceptance:
- Project resolves package and compiles.

### RC-21: Initialize RevenueCat at app startup
Implementation:
- Configure SDK once at launch with iOS public key (`RC_IOS_API_KEY`).
- Start in anonymous mode only if user is not yet authenticated.

Acceptance:
- No startup crashes; SDK initializes once per launch.

### RC-22: Link app auth identity to RevenueCat
Implementation:
- On successful Firebase sign-in: `Purchases.logIn(firebaseUID)`.
- On sign-out: `Purchases.logOut()` and clear local entitlement cache.

Acceptance:
- Same user account restores identical entitlement state across devices.

### RC-23: Load offerings in paywall UI
Implementation:
- Replace static paywall options with live `offerings.current`.
- Gracefully handle unavailable offerings (retry + fallback message).

Acceptance:
- Paywall renders available packages and price strings from RevenueCat.

### RC-24: Implement purchase and restore actions
Implementation:
- Purchase selected package via `Purchases.purchase(package:)`.
- Add Restore button via `Purchases.restorePurchases()`.
- Map canceled/pending/failure states to user-safe UI copy.

Acceptance:
- Successful purchase unlocks premium UI in-session.
- Restore works on a fresh install with same store account.

### RC-25: Observe customer info and gate features
Implementation:
- Centralize entitlement checks in `RevenueCatManager`.
- Drive app gating from `customerInfo.entitlements.active[RC_ENTITLEMENT_ID]`.
- Avoid direct SKU checks in views.

Acceptance:
- Premium features lock/unlock immediately after purchase/expiration/refund events.

### RC-26: Sync entitlement snapshot to backend
Implementation:
- After login/purchase/restore/refresh, POST minimal subscription snapshot to backend for support/debug surfaces.
- Backend remains eventually consistent with webhook source.

Acceptance:
- Backend has user-visible subscription state for diagnostics.

## Phase 3: Backend Webhook + Subscription State

Expected backend area:
- `backend/api/app.py` (or router equivalent)
- `backend/api/services/subscriptions.py` (new)
- `backend/api/models.py` (if needed)

### RC-30: Add subscription schema
Suggested normalized fields:
- `provider`: `revenuecat`
- `appUserId`
- `entitlementId`
- `isActive`
- `productId`
- `store`
- `periodType`
- `expirationAt`
- `gracePeriodExpiresAt`
- `latestEventAt`
- `latestEventType`
- `rawEventId`

Acceptance:
- Single document/queryable row represents current state.

### RC-31: Implement RevenueCat webhook endpoint
Implementation:
- Route: `POST /v1/payments/revenuecat/webhook`
- Verify `Authorization` header matches `RC_WEBHOOK_AUTH`.
- Parse event payload and apply idempotency on unique event ID.

Acceptance:
- Duplicate event delivery does not create inconsistent state.

### RC-32: Map RevenueCat events to entitlement state transitions
Handle at minimum:
- `INITIAL_PURCHASE`
- `RENEWAL`
- `CANCELLATION`
- `UNCANCELLATION`
- `BILLING_ISSUE`
- `EXPIRATION`
- `PRODUCT_CHANGE`
- `TRANSFER`

Acceptance:
- State transitions are deterministic and unit-tested.

### RC-33: Expose subscription status in bootstrap/profile APIs
Implementation:
- Include subscription summary in `GET /v1/bootstrap` response.
- Optional: `GET /v1/user/subscription` endpoint for support tooling.

Acceptance:
- App can hydrate premium state from backend at launch.

## Phase 4: QA and Validation

### RC-40: Sandbox purchase matrix
Test cases:
1. New purchase monthly.
2. New purchase annual.
3. Restore on new install.
4. Cancel subscription in sandbox and verify entitlement update.
5. Billing issue simulation where available.
6. Sign out/sign in with different users and verify isolation.

Acceptance:
- All test cases pass in simulator + device test.

### RC-41: Regression checks (existing app flows)
Validate:
- Google sign-in still works.
- Sign-out still routes to `WelcomeView`.
- Onboarding progression and paywall transitions remain stable.

Commands:
```bash
action_step RC-41 xcodebuild -project "$XCODE_PROJECT_PATH" -scheme "$XCODE_SCHEME" -configuration Debug -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" build
action_step RC-41A ./scripts/run_ios_sim.sh "$SIMULATOR_NAME"
```
Acceptance:
- No auth or navigation regressions after payments integration.

### RC-42: Observability checks
Validate:
- Purchase attempts logged (without PII leakage).
- Webhook events visible with event IDs.
- Subscription status diffs auditable by timestamp.

Acceptance:
- Support can trace a payment state issue end-to-end.

## Phase 5: Rollout and Guardrails

### RC-50: Feature flag strategy
Rollout recommendation:
- Add paywall gate flag (remote config/local override in Debug).
- Enable for internal users first.

Acceptance:
- Ability to disable purchase entry points without app redeploy.

### RC-51: Staged release
Order:
1. Internal QA/TestFlight.
2. Small production cohort.
3. Full rollout after stability window.

Acceptance:
- Error rates and refund anomalies remain within threshold.

### RC-52: Rollback plan
If major issue:
- Disable paywall entry flag.
- Keep existing subscribers active if entitlement is valid.
- Preserve webhook processing (do not drop events).
- Hotfix app/UI and resume staged rollout.

Acceptance:
- Rollback can be executed in minutes without data loss.

## Common Failure Modes and Fixes
1. Offerings are empty:
- Cause: store product not approved/mapped or wrong bundle/store linkage.
- Fix: verify product status and RevenueCat product mapping.

2. Purchase succeeds but app remains locked:
- Cause: app checks SKU instead of entitlement.
- Fix: gate strictly on `premium` entitlement active state.

3. Wrong user gets entitlement:
- Cause: missing `logIn(firebaseUID)` or stale anonymous user.
- Fix: enforce login/logout hooks in auth session manager.

4. Webhook duplicates cause flip-flop state:
- Cause: no idempotency/event ordering strategy.
- Fix: store event IDs and ignore already-processed events.

5. Backend and app disagree on status:
- Cause: delayed webhook or stale cached customer info.
- Fix: trigger explicit customer info refresh and reconcile on next bootstrap.

## Reuse Checklist for Other Projects
Before reusing this runbook in another repo:
1. Replace all env vars and endpoint paths.
2. Decide canonical identity provider for `appUserID` (Firebase UID, internal user ID, etc.).
3. Define one entitlement ID and enforce entitlement-based gating.
4. Add platform-specific SDK setup (iOS/Android/React Native as needed).
5. Implement webhook auth + idempotency before public launch.
6. Add regression checks for that app's auth/navigation flows.
7. Define rollout metrics and rollback trigger thresholds.

## Definition of Done
- RevenueCat offerings load in paywall and display correct prices.
- Purchase/restore flows work in sandbox and TestFlight.
- Premium entitlement gates app features correctly.
- Backend receives and persists webhook-driven subscription state.
- Sign-in/sign-out identity mapping is correct and tested.
- Build/launch validation and execution logs are complete.
