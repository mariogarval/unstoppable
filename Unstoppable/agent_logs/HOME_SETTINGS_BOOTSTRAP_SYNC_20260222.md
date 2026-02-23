# Home Settings Bootstrap Sync

**Date**: 2026-02-22
**Status**: Complete
**Branch**: `codex/profile-email-sync`
**Author**: Codex (GPT-5)

---

## Summary

Aligned Home settings state with backend truth by loading `routineTime` and `notificationsEnabled` from bootstrap at Home entry. Also connected Settings notifications toggle back to `POST /v1/user/profile`, and removed an on-appear routine snapshot write that could overwrite persisted backend routine time.

---

## Problem Statement

`AppSettings` values in `HomeView` were in-memory only and not initialized from backend state, creating drift between onboarding/profile data and Settings UI. `HomeTab` also wrote a routine snapshot on first appearance, which risked clobbering stored `routineTime` before bootstrap settings were applied.

---

## Changes Made

### 1. Bootstrap-backed settings load in HomeView

Added async bootstrap load on Home entry and mapped fields into `AppSettings`.

**Files Created/Modified**:
- `Unstoppable/HomeView.swift` - Added `loadSettingsFromBootstrap()` and parsers for `profile.notificationsEnabled` and `routine.routineTime`.

### 2. Routine time source-of-truth cleanup

Removed duplicated local `routineTime` state from `HomeTab` and bound editing/syncing directly to `settings.routineTime`.

**Files Created/Modified**:
- `Unstoppable/HomeView.swift` - `HomeTab` now uses `@Bindable var settings` for routine time display, edit sheet binding, and routine snapshot payload.

### 3. Notifications settings sync

Settings notifications toggle now writes to profile API to stay aligned with onboarding profile selection.

**Files Created/Modified**:
- `Unstoppable/HomeView.swift` - Added `.onChange` on `settings.notificationsEnabled` and `syncNotifications(enabled:)` using `UserProfileUpsertRequest(notificationsEnabled:)`.

### 4. Launch overwrite guard

Removed `syncRoutineSnapshot()` from `HomeTab.onAppear` to prevent backend routine time overwrite before bootstrap load.

**Files Created/Modified**:
- `Unstoppable/HomeView.swift` - Removed eager snapshot write in `.onAppear`.

---

## Key Results

- Home settings now initialize from backend bootstrap for routine time + notifications.
- Routine time edits persist through existing routine endpoint without launch-time clobbering.
- Notifications toggle in Settings remains connected to profile API contract.
- Build and simulator validation passed after changes.

---

## Verification

```bash
# Verification commands used
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] iOS build succeeds
- [x] Simulator install/launch succeeds on `iPhone 17 Pro`
- [x] Home code compiles with bootstrap settings load and settings sync hooks

---

## Related Documents

- `PROFILE_COMPLETION_ROUTING_20260221.md` - prior bootstrap-driven routing integration in app
- `UNSTOPPABLE_LOGS_20260212.md` - earlier API sync rollout for onboarding/home data
