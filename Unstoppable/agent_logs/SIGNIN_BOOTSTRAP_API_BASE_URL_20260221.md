# Sign-In Bootstrap API Base URL Fix

**Date**: 2026-02-21
**Status**: Code Complete
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

Investigated the welcome-screen error message shown after successful Google sign-in: "Signed in, but failed to load your account. Please try again." The issue path was post-auth bootstrap failing, and a concrete config mismatch was found in Debug API base URL settings.

---

## Problem Statement

Sign-in succeeded, but `WelcomeView` could not fetch `/v1/bootstrap`, which triggers the generic account-load failure banner. The app was still configured with an older Cloud Run URL in Debug/fallback API configuration.

---

## Changes Made

### 1. Updated Debug API base URL in Xcode project settings

**Files Created/Modified**:
- `Unstoppable.xcodeproj/project.pbxproj` - changed Debug `API_BASE_URL` from `https://unstoppable-api-1094359674860.us-central1.run.app` to `https://unstoppable-api-qri3urt3ha-uc.a.run.app`.

### 2. Updated runtime fallback API URL

**Files Created/Modified**:
- `Unstoppable/Networking/APIClient.swift` - changed `fallbackBaseURLString` to `https://unstoppable-api-qri3urt3ha-uc.a.run.app`.

---

## Verification

```bash
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] Debug simulator build succeeds.
- [x] App installs and launches on `iPhone 17 Pro` simulator.

---

## Next Steps

- Re-test sign-in flow in simulator/device and confirm `/v1/bootstrap` returns success after auth.
- If failure persists, capture server-side token verification reason (currently surfaced as generic `Invalid auth token`).
