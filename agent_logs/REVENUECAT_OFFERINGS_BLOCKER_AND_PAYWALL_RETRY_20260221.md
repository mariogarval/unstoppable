# RevenueCat Offerings Blocker and Paywall Retry Handling

**Date**: 2026-02-21
**Status**: In Progress
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

Validated current RevenueCat runtime after App Store metadata cleanup and confirmed the SDK key path is correct, but offerings are still empty at runtime (`OfferingsManager.Error`). Implemented a paywall UX fix so the primary CTA no longer silently falls through when offerings are unavailable; it now presents retry/loading behavior and refreshes offerings. Added a local StoreKit configuration and wired the `Unstoppable` scheme so full purchase UX can be tested immediately from Xcode while App Store Connect/RevenueCat propagation catches up.

---

## Problem Statement

The paywall continued to behave ambiguously when RevenueCat offerings could not be fetched. Users could select a plan but would not get a real purchase flow because there were no dynamic packages loaded from StoreKit/RevenueCat.

---

## Changes Made

### 1. Paywall Fallback Behavior Hardened

Updated the paywall CTA and empty-offerings handling to make failure states explicit and actionable.

**Files Modified**:
- `Unstoppable/onboarding/PaywallView.swift`
  - CTA text now reflects loading/retry state when offerings are unavailable.
  - CTA icon switches to retry icon when offerings are empty.
  - Added explanatory message under plan cards for unavailable subscriptions.
  - `handleContinueTapped()` now refreshes offerings and shows explicit error when no dynamic package is available, instead of proceeding via non-purchase fallback.

### 2. Local StoreKit Test Configuration Added

Added a local StoreKit file with matching subscription product IDs and connected it to the app launch scheme.

**Files Modified**:
- `Unstoppable/StoreKit/UnstoppableLocal.storekit`
  - Added local recurring subscriptions for `monthly` (`P1M`) and `yearly` (`P1Y`) under one `Premium` subscription group.
- `Unstoppable.xcodeproj/xcshareddata/xcschemes/Unstoppable.xcscheme`
  - Added `<StoreKitConfigurationFileReference>` to load `../Unstoppable/StoreKit/UnstoppableLocal.storekit` on launch.
- `README.md`
  - Documented local StoreKit testing path and updated paywall fallback behavior description.

### 3. Settings Paywall Test Entry Behind Feature Flag

Added a Settings-only paywall launch button, gated behind a runtime flag so it only appears in test scenarios.

**Files Modified**:
- `Unstoppable/HomeView.swift`
  - Added `Open Paywall (Test)` button in Settings (`Testing` section).
  - Added sheet presentation of `PaywallView()` from Settings.
  - Added `REVENUECAT_SHOW_SETTINGS_PAYWALL_TEST_BUTTON` Info.plist flag reader.
- `Unstoppable/Config/RevenueCat.xcconfig`
  - Added default `REVENUECAT_SHOW_SETTINGS_PAYWALL_TEST_BUTTON = NO`.
- `Unstoppable/Config/Secrets.local.xcconfig.example`
  - Added local override template for `REVENUECAT_SHOW_SETTINGS_PAYWALL_TEST_BUTTON`.
- `Unstoppable/Info.plist`
  - Added `REVENUECAT_SHOW_SETTINGS_PAYWALL_TEST_BUTTON` build-setting injection.
- `README.md`
  - Added instructions to enable Settings paywall test entry via local secrets.

---

## Validation Results

- `xcodebuild` succeeds after paywall changes.
- `./scripts/run_ios_sim.sh "iPhone 17 Pro"` succeeds (build/install/launch).
- `Unstoppable/StoreKit/UnstoppableLocal.storekit` parses as valid JSON.
- `xcodebuild` and simulator launch succeed after adding Settings paywall test feature flag wiring.
- Runtime logs still show offerings fetch failure:
  - `RevenueCat.OfferingsManager.Error error 1`
  - Product status now `READY_TO_SUBMIT` (improved from previous `MISSING_METADATA`)
  - Offerings `default` / `default_copy` still flagged by RevenueCat health report.

---

## Key Decision

- Keep paywall deterministic when RevenueCat offerings are unavailable: show retry-oriented UI and avoid non-purchase continuation through the main CTA.

---

## Executed Commands

```bash
git status --short
git branch --show-current
rg -n 'entitlement|monthly|yearly|default|premium|Unstoppable Pro|package|offering|REVENUECAT' Unstoppable/Payments/RevenueCatManager.swift Unstoppable/onboarding/PaywallView.swift PAYMENTS_PLAN.md
./scripts/run_ios_sim.sh "iPhone 17 Pro"
xcrun simctl spawn booted log show --last 5m --style compact --predicate 'process == "Unstoppable" AND (eventMessage CONTAINS[c] "RevenueCat" OR eventMessage CONTAINS[c] "offering" OR eventMessage CONTAINS[c] "purchase")'
rg --files -g '*.storekit' .
rg -n 'StoreKitConfigurationFileReference|StoreKit|storekit' Unstoppable.xcodeproj/xcshareddata/xcschemes/Unstoppable.xcscheme Unstoppable.xcodeproj/project.pbxproj
nl -ba Unstoppable/onboarding/PaywallView.swift
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
xcrun simctl spawn booted log show --last 3m --style compact --predicate 'process == "Unstoppable" AND (eventMessage CONTAINS[c] "offering" OR eventMessage CONTAINS[c] "RevenueCat")'
git diff -- Unstoppable/onboarding/PaywallView.swift
ruby -rjson -e 'JSON.parse(File.read("Unstoppable/StoreKit/UnstoppableLocal.storekit")); puts "valid json"'
rg -n 'StoreKitConfigurationFileReference|UnstoppableLocal.storekit' Unstoppable.xcodeproj/xcshareddata/xcschemes/Unstoppable.xcscheme
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

---

## Next Steps

1. In RevenueCat dashboard, keep only the intended current offering (`default`) mapped to valid App Store products.
2. In App Store Connect, move subscriptions beyond `READY_TO_SUBMIT` with full subscription metadata/workflow completion for release readiness.
3. Test full local purchase UX from Xcode using the `Unstoppable` scheme with `Unstoppable/StoreKit/UnstoppableLocal.storekit`.
4. Set `REVENUECAT_SHOW_SETTINGS_PAYWALL_TEST_BUTTON = YES` in `Unstoppable/Config/Secrets.local.xcconfig` when you want direct Settings access to paywall during testing.
5. Re-test live offerings load; once packages appear from RevenueCat/App Store, run purchase/restore matrix without local StoreKit override.
