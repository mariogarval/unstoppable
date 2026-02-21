# Google Sign-In Bundle ID Alignment

**Date**: 2026-02-17
**Status**: Complete
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

The app configuration was aligned to the new bundle ID `app.unstoppable.unstoppable` and validated with fresh simulator build/launch runs. During verification, a Google Sign-In callback mismatch was detected between Firebase `REVERSED_CLIENT_ID` and `CFBundleURLSchemes`, then corrected. Final validation succeeded (`BUILD SUCCEEDED`, app launched on iPhone 17 Pro simulator).

---

## Problem Statement

After changing the iOS bundle ID, Google Sign-In can fail if Firebase iOS app metadata and `Info.plist` callback URL schemes are not updated consistently. The objective was to confirm the app uses the new bundle ID end-to-end and that OAuth callback routing matches the regenerated Firebase plist.

---

## Changes Made

### 1. Bundle ID + Firebase Metadata Alignment

Aligned checked-in config values and runbook references to the migrated bundle ID.

**Files Created/Modified**:
- `Unstoppable/GoogleService-Info.plist` - `BUNDLE_ID` set to `app.unstoppable.unstoppable`.
- `GOOGLE_AUTH_PLAN.md` - updated bundle ID references and env example values.
- `PAYMENTS_PLAN.md` - updated reusable `IOS_BUNDLE_ID` value.

### 2. Google Callback URL Scheme Correction

Compared Firebase `REVERSED_CLIENT_ID` with the app URL scheme and corrected mismatch.

Mismatch observed:
- `GoogleService-Info.plist` `REVERSED_CLIENT_ID`:
  `com.googleusercontent.apps.1094359674860-n4jm9ptghhv9o5nc6tvir6dli7fmhloa`
- `Info.plist` `CFBundleURLSchemes[0]` (before fix):
  `com.googleusercontent.apps.1094359674860-ehqjbqas76tofkpu9fb02enovurr00l4`

Applied fix:
- `Unstoppable/Info.plist` - URL scheme updated to `com.googleusercontent.apps.1094359674860-n4jm9ptghhv9o5nc6tvir6dli7fmhloa`.

### 3. Build + Launch Verification

Validated with project build and simulator launch scripts.

**Files Created/Modified**:
- `README.md` - added explicit note to regenerate Firebase plist and re-check URL schemes after bundle changes.
- `Unstoppable/agent_logs/BUNDLE_ID_MIGRATION_20260217.md` - codex session record.
- `Unstoppable/agent_logs/__AGENT_INDEX.md` - index entry for migration session.

---

## Key Results

- App builds successfully for simulator with migrated bundle ID.
- App launches successfully via simulator script with bundle id `app.unstoppable.unstoppable`.
- Google Sign-In callback scheme now matches Firebase config.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Keep bundle ID as `app.unstoppable.unstoppable` | Must match newly created App Store Connect app and RevenueCat app configuration. |
| Use Firebase plist as source of truth for callback scheme | Prevents stale manual URL scheme values after iOS app re-registration in Firebase. |
| Verify with both `xcodebuild` and simulator launch script | Confirms compile/link + runtime install/launch path used by this project. |

---

## Verification

```bash
# Core validation commands
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' /Users/luisgalvez/Projects/unstoppable/Unstoppable/GoogleService-Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' /Users/luisgalvez/Projects/unstoppable/Unstoppable/Info.plist
```

- [x] Build output reported `** BUILD SUCCEEDED **`.
- [x] Simulator launch script installed and launched app (`app.unstoppable.unstoppable` PID observed).
- [x] Firebase `REVERSED_CLIENT_ID` equals app `CFBundleURLSchemes[0]`.

---

## Next Steps

- Execute manual Google Sign-In in simulator and confirm callback/auth completes.
- Execute RevenueCat paywall test (load offerings, purchase sandbox product, restore purchase).

---

## Related Documents

- `Unstoppable/agent_logs/BUNDLE_ID_MIGRATION_20260217.md` - codex migration session.
- `GOOGLE_AUTH_PLAN.md` - detailed auth runbook and troubleshooting history.
- `PAYMENTS_PLAN.md` - payments runbook updated for new bundle ID.
