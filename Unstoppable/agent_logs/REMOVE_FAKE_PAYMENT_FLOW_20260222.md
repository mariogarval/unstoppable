# Remove Fake Payment Flow

**Date**: 2026-02-22
**Status**: Complete
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

Removed all fake paywall runtime code paths and feature-flag configuration now that RevenueCat test products are working. The app now uses live `RevenueCatManager` directly for app init, auth lifecycle, and paywall flow.

---

## Changes Made

### 1. Removed fake runtime routing and managers

- Switched app startup from `PaymentManagerRouter` to `RevenueCatManager.shared`.
- Switched auth restore/sign-in/sign-out hooks to `RevenueCatManager.shared.logIn/logOut`.
- Removed paywall routing enum/switch and kept the live paywall as the only `PaywallView`.
- Deleted fake implementation files:
  - `Unstoppable/Payments/FakePaymentManager.swift`
  - `Unstoppable/Payments/PaymentRuntimeMode.swift`
  - `Unstoppable/onboarding/FakePaywallView.swift`

### 2. Removed feature-flag config/plumbing

- Removed `REVENUECAT_FAKE_SUBSCRIPTION_MODE` from:
  - `Unstoppable/Config/RevenueCat.xcconfig`
  - `Unstoppable/Config/Secrets.local.xcconfig.example`
  - `Unstoppable/Info.plist`
- Removed fake file/build references from `Unstoppable.xcodeproj/project.pbxproj`.
- Updated `README.md` to remove fake-mode documentation.

---

## Verification

```bash
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] Build succeeded: `** BUILD SUCCEEDED **`
- [x] Simulator launch succeeded: app installed and launched (`app.unstoppable.unstoppable`)

---

## Related Documents

- `FAKE_PAYMENT_MANAGER_SPLIT_20260221.md` - previous session that introduced the fake manager split.
