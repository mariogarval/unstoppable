# Fake Payment Manager Split

**Date**: 2026-02-21
**Status**: Complete
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

Split fake payment behavior out of `RevenueCatManager` so live RevenueCat code stays isolated and easier to maintain. Added a dedicated `FakePaymentManager` and a runtime router keyed off `REVENUECAT_FAKE_SUBSCRIPTION_MODE` to choose live vs fake behavior across app init, auth session hooks, and paywall rendering.

---

## Changes Made

### 1. Separated runtime mode and manager routing

Added centralized runtime mode parsing (`live`, `fakeActive`, `fakeInactive`) and routing helpers for configure/login/logout.

**Files Created/Modified**:
- NEW: `Unstoppable/Payments/PaymentRuntimeMode.swift` - runtime mode parser and `PaymentManagerRouter`.

### 2. Isolated fake payment flow

Moved fake plans, fake purchase/restore state, and fake subscription snapshot sync into a dedicated manager.

**Files Created/Modified**:
- NEW: `Unstoppable/Payments/FakePaymentManager.swift` - fake offerings and deterministic snapshot writes.

### 3. Kept RevenueCat manager live-only

Removed fake-mode branching and fake data paths from `RevenueCatManager` so it now handles only live RevenueCat config, offerings, purchases/restores, and optional backend snapshot sync.

**Files Created/Modified**:
- `Unstoppable/Payments/RevenueCatManager.swift` - live-only cleanup.

### 4. Switched app/auth/paywall call sites to routed managers

Ensured fake mode does not call live RevenueCat manager in init/auth flows and fake paywall uses fake manager directly.

**Files Created/Modified**:
- `Unstoppable/UnstoppableApp.swift` - uses `PaymentManagerRouter.configureIfNeeded()`.
- `Unstoppable/Auth/AuthSessionManager.swift` - uses `PaymentManagerRouter.logIn/logOut()`.
- `Unstoppable/onboarding/PaywallView.swift` - mode routing via `PaymentManagerRouter.currentRuntimeMode`; fake view now uses `FakePaymentManager.shared`.
- `Unstoppable.xcodeproj/project.pbxproj` - added new payment files to target sources.

---

## Verification

```bash
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] Resolved compile error from first pass (`main actor-isolated static property 'currentRuntimeMode' can not be referenced from a nonisolated context`) by making the runtime property nonisolated.
- [x] `xcodebuild` finished with `** BUILD SUCCEEDED **`.
- [x] `run_ios_sim.sh` finished with app install + launch (`app.unstoppable.unstoppable: 35534`).

---

## Related Documents

- `agent_logs/PAYMENTS_FAKE_SUBSCRIPTION_AND_CANONICAL_PAYMENT_OPTION_20260221.md` - broader fake mode + backend canonical paymentOption implementation.
- `agent_logs/REVENUECAT_OFFERINGS_BLOCKER_AND_PAYWALL_RETRY_20260221.md` - offerings outage context that motivated fake mode.

---

## Follow-up Update (Same Day)

- Extracted `FakePaywallView` into `Unstoppable/onboarding/FakePaywallView.swift`.
- Removed fake UI implementation block from `Unstoppable/onboarding/PaywallView.swift`.
- Added new onboarding source file to `Unstoppable.xcodeproj/project.pbxproj`.
- Promoted `PlanCard` and `DismissButton` from file-private to shared in-module visibility so both paywall files can reuse them.
- Revalidated with:
  - `xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build`
