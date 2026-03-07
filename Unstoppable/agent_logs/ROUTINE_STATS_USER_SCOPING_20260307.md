# Routine Stats User Scoping

**Date**: 2026-03-07
**Status**: Complete
**Branch**: `agentic-dev-v1`
**Author**: Codex (GPT-5)

---

## Summary

Fixed a local app-side bug where routine stats and routine draft state could leak across users on the same device because they were stored under shared `UserDefaults` keys and held in singleton memory. Added user-scoped local storage for streak/routine-progress state, refreshed that scope on auth transitions, and corrected the local testing reset flow so it also clears the scoped streak data.

---

## Problem Statement

Routine stats in the Stats tab were not isolated per current user. After signing in with another account, or after using the in-app local reset and starting again, the next user could still see the prior user's streak and routine-done totals from local device storage.

---

## Changes Made

### 1. Scoped routine stats storage to the active user

Moved streak persistence to user-scoped keys and made the singleton reload its local state whenever the active Firebase auth user changes. This covers both persisted `UserDefaults` data and in-memory singleton state.

**Files Created/Modified**:
- `Unstoppable/StreakManager.swift` - changed streak persistence from shared keys to scoped keys, reset in-memory state on scope switches, and added shared key helpers for related local storage
- `Unstoppable/Auth/AuthSessionManager.swift` - refreshed streak storage scope on session restore, sign-in, and sign-out

### 2. Scoped routine draft state used by routine creation/home handoff

Scoped the pending routine draft key so a routine drafted by one user or guest session is not loaded by another user on the same device.

**Files Created/Modified**:
- `Unstoppable/RoutineCreationView 2.swift` - saved pending routine tasks under a user-scoped key
- `Unstoppable/HomeView.swift` - loaded and removed pending routine tasks from the matching user-scoped key

### 3. Fixed the in-app local reset helper

After initial implementation, manual verification showed the `Reset Local Profile (Test)` flow still reproduced the old streak because it only cleared onboarding/profile keys and did not remove the scoped streak keys. Added a dedicated reset helper to clear all local scoped streak and routine draft keys.

**Files Created/Modified**:
- `Unstoppable/StreakManager.swift` - added `clearLocalTestingState()` for local testing cleanup
- `Unstoppable/HomeView.swift` - invoked the new cleanup helper from `resetLocalProfileForTesting()`

---

## Key Results

The app now stores local routine stats per active Firebase user instead of per device-wide key. The local testing reset path also clears the scoped streak data, which prevents false carry-over when restarting with a new user on the same simulator/device.

| Metric | Before | After |
|--------|--------|-------|
| Local streak key scope | Shared across all users on device | Scoped by active user id or `guest-local` |
| In-memory singleton reset on user switch | No | Yes |
| Local test reset clears streak data | No | Yes |

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Keep the fix app-side and targeted | Backend endpoints were already user-scoped; the confirmed leak was local persistence and singleton memory |
| Reuse `StreakManager` as the source of scoped-key logic | Avoided broad project changes and kept the routines/stats storage logic in one place |
| Fix the reset helper in the same session | The user reproduced a remaining stale-stats case immediately after the initial fix, and the root cause was local reset incompleteness |

---

## Verification

Initial verification exposed implementation issues during compilation and helped catch the incomplete reset path:
- Build failed at first because a new helper symbol was not available to the target and some methods needed explicit `return`s after adding scope refresh calls
- A second build failed due to incorrect optional chaining on `Auth.auth().currentUser?.uid`
- After those fixes, both the direct build and simulator workflow succeeded
- User follow-up identified that `Reset Local Profile (Test)` still left scoped streak data behind; fixed and revalidated

```bash
# Baseline
git status --short
git branch --show-current

# Verification commands used
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] Captured baseline repo state
- [x] Verified direct `xcodebuild` succeeds
- [x] Verified `./scripts/run_ios_sim.sh "iPhone 17 Pro"` builds, installs, and launches the app
- [x] Fixed local reset path so scoped streak data is cleared for local testing

---

## Key Learnings

1. **User-scoped persistence must include reset utilities**: Scoping runtime storage fixed cross-user leakage, but test/reset flows also need to understand the new key scheme or they will silently preserve stale state.
2. **Singletons need auth-transition reload behavior**: Fixing the `UserDefaults` key alone was insufficient because `StreakManager.shared` could still hold the previous user's state in memory.

---

## Next Steps

- Consider user-scoping `hasCompletedOnboarding` and `hasCreatedRoutine` as well, since they are still stored under shared local keys.
- If stale stats appear again after local reset with a genuinely different signed-in account, inspect `/v1/bootstrap` for remote streak data tied to that account rather than local storage.

---

## Related Documents

- `HOME_SETTINGS_BOOTSTRAP_SYNC_20260222.md` - another app-side persistence/bootstrap synchronization change in Home
- `PROFILE_COMPLETION_ROUTING_20260221.md` - related auth/bootstrap routing behavior on app side
