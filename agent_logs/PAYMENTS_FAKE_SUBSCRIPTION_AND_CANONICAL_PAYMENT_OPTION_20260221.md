# Payments Fake Subscription Mode + Canonical paymentOption Ownership

**Date**: 2026-02-21
**Status**: Code Complete
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

Implemented the payments flow improvements to unblock QA while RevenueCat offerings remain unreliable. The app now supports a debug fake-subscription mode (`off|active|inactive`) that can drive deterministic paywall behavior and API snapshot writes, and backend now treats `users/{uid}/payments/subscription.paymentOption` as canonical while preserving profile mirroring for compatibility.

---

## Problem Statement

The app needed a reliable way to test payment persistence even when RevenueCat offerings fail to load. At the same time, `paymentOption` ownership was split across profile and payment documents, which created schema ambiguity and made completion logic harder to reason about.

---

## Changes Made

### 1. Added debug fake-subscription mode in iOS app

Implemented runtime fake mode controlled by build config, with deterministic package data and subscription snapshot sync.

**Files Modified**:
- `Unstoppable/Payments/RevenueCatManager.swift`
  - Added runtime mode parsing for `REVENUECAT_FAKE_SUBSCRIPTION_MODE`.
  - Added fake plans (annual/monthly) with stable package IDs and product IDs.
  - Added fake-mode purchase/restore/login/logout/refresh behavior.
  - Added fake snapshot writes to `/v1/payments/subscription/snapshot` with deterministic fields (`store=debug_fake`, `periodType=normal`, entitlement IDs gated by fake active state).
- `Unstoppable/Config/RevenueCat.xcconfig`
  - Added `REVENUECAT_FAKE_SUBSCRIPTION_MODE = off` default.
- `Unstoppable/Config/Secrets.local.xcconfig.example`
  - Added local override example for `REVENUECAT_FAKE_SUBSCRIPTION_MODE`.
- `Unstoppable/Info.plist`
  - Added build-setting injection key `REVENUECAT_FAKE_SUBSCRIPTION_MODE`.
- `Unstoppable/onboarding/PaywallView.swift`
  - Refactored into routing wrapper + split views:
    - `RevenueCatPaywallView` for live offerings flow.
    - `FakePaywallView` for fake-mode simulation flow.
  - Routing controlled by `REVENUECAT_FAKE_SUBSCRIPTION_MODE` (`active`/`inactive` -> fake view).

### 2. Canonicalized backend `paymentOption` ownership

Made subscription doc primary for completion logic and kept profile as a mirror.

**Files Modified**:
- `backend/api/src/app.py`
  - Added `_effective_payment_option(profile, subscription)` helper.
  - Updated `_profile_completion(...)` to resolve `paymentOption` from subscription first, then profile fallback.
  - Updated `POST /v1/user/profile` to write canonical `users/{uid}/payments/subscription.paymentOption` plus metadata (`provider=profile_sync`, `source=profile_payment_option`, `updatedAt`).
  - Kept existing snapshot/webhook profile-mirror behavior.

### 3. Added one-time migration script

Added script to backfill canonical subscription payment option from profile data.

**Files Added**:
- `backend/api/scripts/migrate_payment_option_to_subscription.py`
  - Supports `--email`, `--uid`, or `--all`.
  - Defaults to dry-run; requires `--apply` for writes.
  - Copies only when subscription canonical field is missing.
  - Preserves existing canonical values and reports conflicts when profile/subscription differ.

### 4. Updated docs and runbooks

Updated operational docs to reflect new fake mode and canonical/mirror strategy.

**Files Modified**:
- `README.md`
  - Documented paywall routing split between live and fake views.
- `backend/api/README.md`
- `backend/api/API_RUNBOOK.md`
- `Unstoppable/Networking/Models.swift` (added optional `subscription` field on `BootstrapResponse` for payload alignment)

---

## Key Results

- Payments QA can proceed without live offerings by toggling:
  - `REVENUECAT_FAKE_SUBSCRIPTION_MODE = active`
  - `REVENUECAT_FAKE_SUBSCRIPTION_MODE = inactive`
- Backend completion logic now uses canonical payment-domain location first:
  - `users/{uid}/payments/subscription.paymentOption`
- Migration path is available for existing users through a safe dry-run-first script.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Keep fake mode controlled via xcconfig, not runtime UI | Matches testing requirement while keeping production behavior isolated. |
| Canonicalize `paymentOption` in subscription doc and mirror to profile | Aligns ownership with payment domain while preserving onboarding compatibility. |
| Keep existing endpoints and contracts | Avoids churn/risk in app-backend integration and rollout. |

---

## Verification

```bash
python3 -m py_compile backend/api/src/app.py backend/api/scripts/migrate_payment_option_to_subscription.py
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] Python compile checks pass for updated backend app and new migration script.
- [x] iOS simulator build succeeds.
- [x] Scripted simulator install/launch succeeds for `app.unstoppable.unstoppable`.

---

## Next Steps

1. Run migration dry-run against target scope:
   - `python scripts/migrate_payment_option_to_subscription.py --all`
2. Apply migration:
   - `python scripts/migrate_payment_option_to_subscription.py --all --apply`
3. Validate sample users with:
   - `python scripts/check_user_payments.py --email <user>`
4. Toggle fake mode (`active` then `inactive`) and confirm snapshot/bootstrap parity in Firestore.

---

## Related Documents

- `agent_logs/REVENUECAT_OFFERINGS_BLOCKER_AND_PAYWALL_RETRY_20260221.md` - offerings/runtime blocker context.
- `agent_logs/REVENUECAT_PAYMENTS_ROLLOUT_STATUS_20260217.md` - broader payments rollout status.
