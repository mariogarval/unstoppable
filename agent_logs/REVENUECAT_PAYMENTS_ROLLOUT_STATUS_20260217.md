# RevenueCat Payments Rollout Status

**Date**: 2026-02-17
**Status**: In Progress
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

This log consolidates payments work completed so far for the Unstoppable app using RevenueCat. App-side integration is implemented and validated, backend webhook/state endpoints are implemented locally, and the app can now run in app-only mode by default via feature flag. Remaining work is mainly dashboard/runtime verification and final end-to-end purchase validation.

---

## Problem Statement

The app needed production-grade subscription infrastructure with RevenueCat while preserving existing onboarding/navigation behavior and supporting a reusable rollout process. The implementation had to cover secure SDK key handling, entitlement-based gating, purchase/restore flows, identity mapping with Firebase auth, and optional backend synchronization.

---

## Changes Made

### 1. RevenueCat SDK + Paywall Integration (iOS)

Implemented app-side RevenueCat integration and connected paywall flows to live offerings.

**Files Created/Modified**:
- `Unstoppable/Payments/RevenueCatManager.swift` - SDK config, offerings load, purchase/restore, entitlement state, delegate updates.
- `Unstoppable/onboarding/PaywallView.swift` - live offerings + purchase/restore flow with fallback behavior.
- `Unstoppable/UnstoppableApp.swift` - app startup RevenueCat configure hook.
- `Unstoppable/Auth/AuthSessionManager.swift` - `Purchases.logIn(firebaseUID)` on auth and `Purchases.logOut()` on sign-out.
- `Unstoppable.xcodeproj/project.pbxproj` - RevenueCat package wiring and app target linkage.
- `Unstoppable.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` - pinned package resolution.

### 2. Secure Key + Config Management

Removed hardcoded-key approach and standardized local-only secret injection.

**Files Created/Modified**:
- `Unstoppable/Config/RevenueCat.xcconfig` - default values including backend sync flag.
- `Unstoppable/Config/Secrets.local.xcconfig.example` - local secret template.
- `Unstoppable/Info.plist` - injected `REVENUECAT_IOS_API_KEY` and runtime flags.
- `.gitignore` - local secret ignore coverage.

### 3. Backend Subscription State + Webhook (Local Implementation)

Implemented local backend payments routes for webhook ingestion and subscription state surfaces.

**Files Created/Modified**:
- `backend/api/src/app.py`
  - `POST /v1/payments/revenuecat/webhook`
  - `POST /v1/payments/subscription/snapshot`
  - `GET /v1/user/subscription`
  - `GET /v1/bootstrap` now includes `subscription`
- `backend/api/README.md` - endpoint and env documentation (`REVENUECAT_WEBHOOK_AUTH`).

### 4. App-Side-Only Runtime Mode (Feature Flag)

Made backend subscription snapshot sync optional so app-side purchases can run without Flask API dependency.

**Files Created/Modified**:
- `Unstoppable/Payments/RevenueCatManager.swift` - gated snapshot sync behind `REVENUECAT_ENABLE_BACKEND_SYNC`.
- `Unstoppable/Config/RevenueCat.xcconfig` - default `REVENUECAT_ENABLE_BACKEND_SYNC = NO`.
- `Unstoppable/Config/Secrets.local.xcconfig.example` - explicit local override option.
- `README.md` and `PAYMENTS_PLAN.md` - documented flag behavior and expectations.

### 5. Bundle ID Alignment for Store + Firebase + Payments

Aligned project to new bundle ID and corrected Google callback scheme mismatch discovered during verification.

**Files Created/Modified**:
- `Unstoppable.xcodeproj/project.pbxproj` - `PRODUCT_BUNDLE_IDENTIFIER = app.unstoppable.unstoppable`.
- `Unstoppable/GoogleService-Info.plist` - updated `BUNDLE_ID`.
- `Unstoppable/Info.plist` - URL scheme updated to match Firebase `REVERSED_CLIENT_ID`.
- `GOOGLE_AUTH_PLAN.md`, `PAYMENTS_PLAN.md`, `README.md` - updated references.

---

## Key Results

- RevenueCat app-side payments flow is implemented and build-validated.
- Entitlement gating is centralized and identity-linked to Firebase user lifecycle.
- Backend payment endpoints are implemented locally for eventual server-authoritative workflows.
- App can operate payments in app-only mode by default (`REVENUECAT_ENABLE_BACKEND_SYNC=NO`).
- Simulator build/launch validations succeeded repeatedly on `iPhone 17 Pro`.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Entitlement-based gating (`premium`) | Avoid brittle SKU checks and keep access logic stable across products/offers. |
| Firebase UID as RevenueCat `appUserID` | Ensures deterministic identity mapping across restore/sign-in/sign-out paths. |
| Keep backend sync optional via runtime flag | Supports incremental rollout and local app-only validation without backend dependency. |
| Keep webhook logic idempotent + order-safe | Prevent duplicate/out-of-order event corruption in subscription state. |
| Secure key injection via local xcconfig | Prevents key leakage in tracked source/config files. |

---

## Verification

```bash
# Representative validation commands used
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
python3 -m py_compile backend/api/src/app.py
rg -n "@app\\.(get|post|put)\\(\"/v1/(payments|user/subscription|bootstrap)" backend/api/src/app.py
```

- [x] iOS builds succeeded after each major payments milestone.
- [x] Simulator launch/install path succeeded with current bundle ID.
- [x] Backend payments module compiles (`py_compile`) in local checks.
- [ ] Manual sandbox purchase + restore matrix fully completed on final dashboard configuration.
- [ ] Runtime webhook delivery verification against deployed backend.

---

## Next Steps

- Complete RevenueCat dashboard verification: entitlement/package mapping and default offering resolution.
- Run full sandbox test matrix: purchase, restore, relaunch, entitlement revoke/expire handling.
- Decide deployment plan for backend webhook routes and secret injection in Cloud Run.
- Add final release checklist for production key cutover (non-test key) and monitoring.

---

## Related Documents

- `PAYMENTS_PLAN.md` - reusable implementation runbook and phased checklist.
- `Unstoppable/codex_logs/REVENUECAT_PHASE1_20260212.md` - app integration phase log.
- `Unstoppable/codex_logs/REVENUECAT_PHASE2_20260212.md` - app/backend snapshot sync phase log.
- `backend/codex_logs/REVENUECAT_BACKEND_PHASE3_20260212.md` - backend webhook/state phase log.
- `Unstoppable/codex_logs/REVENUECAT_APP_SIDE_FLAG_20260213.md` - app-only feature flag decision log.
