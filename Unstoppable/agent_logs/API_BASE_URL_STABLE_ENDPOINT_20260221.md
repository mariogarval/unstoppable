# API Base URL Stable Endpoint Revert

**Date**: 2026-02-21
**Status**: Complete
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

Reverted app API endpoint configuration to the stable Cloud Run service URL so the app does not depend on revision-specific hostnames. Updated both Debug build setting and runtime fallback URL to `https://unstoppable-api-1094359674860.us-central1.run.app`.

---

## Changes Made

### 1. Debug API base URL

**Files Created/Modified**:
- `Unstoppable.xcodeproj/project.pbxproj` - set Debug `API_BASE_URL` to `https://unstoppable-api-1094359674860.us-central1.run.app`.

### 2. Runtime fallback API URL

**Files Created/Modified**:
- `Unstoppable/Networking/APIClient.swift` - set `fallbackBaseURLString` to `https://unstoppable-api-1094359674860.us-central1.run.app`.

---

## Verification

```bash
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] Debug build succeeded.
- [x] App installed and launched in simulator.

---

## Next Steps

- Re-test Google sign-in flow and capture whether `/v1/bootstrap` still fails.
- If the error persists, inspect backend token verification details for the issued Firebase ID token.
