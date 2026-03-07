# Home Routine State Isolation

**Date**: 2026-03-07
**Status**: Complete
**Branch**: `agentic-dev-v1`
**Author**: Codex (GPT-5)

---

## Summary

Fixed a chain of app-side state-isolation bugs that caused guest and signed-in users to share routine-related local data on the same device. The session also fixed a restore bug where checked routine tasks could disappear after navigating from Home to Stats and back, especially after auth restore, and hardened Home settings bootstrap against late-response overwrites.

---

## Problem Statement

Routine, onboarding, and streak-related local state was not consistently scoped to the active auth context. That caused signed-in users to inherit guest routine data, guests to appear reset after auth round-trips, signed-in streak caches to be wiped by local profile reset, and restored task completion to disappear after tab navigation because bootstrap/UI state and `StreakManager` were not hydrated consistently.

---

## Changes Made

### 1. Separated guest and signed-in local routine/streak state

Scoped local streak persistence, routine draft state, and onboarding/routine flags to the active auth scope so guest and signed-in flows no longer read the same device-wide values.

**Files Created/Modified**:
- `Unstoppable/StreakManager.swift` - scoped streak storage, scoped onboarding/routine flags, reset helpers, and completion hydration helpers
- `Unstoppable/UnstoppableApp.swift` - routed launch-time onboarding flags through scoped storage
- `Unstoppable/WelcomeView.swift` - updated onboarding completion writes to scoped storage
- `Unstoppable/HomeView.swift` - updated routine draft loading/reset handling and scoped flow reads
- `Unstoppable/RoutineCreationView 2.swift` - saved routine draft/completion state using scoped keys
- `Unstoppable/onboarding/PaywallView.swift` - wrote `hasCreatedRoutine` through scoped storage

### 2. Stopped guest data from being merged into authenticated accounts

Removed the automatic guest-data flush on auth transition so signing in with Google or Apple no longer promotes guest-local routine/profile state into the authenticated account by accident.

**Files Created/Modified**:
- `Unstoppable/Auth/AuthSessionManager.swift` - removed `flushPendingGuestDataIfNeeded()` from auth restore/sign-in transitions

### 3. Stabilized routine completion restore across Home and Stats

Changed task completion tracking to use deterministic completion keys instead of transient UUIDs, preserved task identity during routine hydration, and hydrated `StreakManager` from bootstrap progress so restored checks survive Home -> Stats -> Home navigation after login.

**Files Created/Modified**:
- `Unstoppable/StreakManager.swift` - switched completion tracking to stable string keys and added `hydrateTodayCompletion(...)`
- `Unstoppable/HomeView.swift` - applied stable completion keys, deterministic restore on bootstrap, and bootstrap-to-manager completion hydration
- `Unstoppable/RoutineCreationView 2.swift` - preserved task ids when saving routine snapshots
- `Unstoppable/RoutineTimerView.swift` - reported completed tasks with stable completion keys

### 4. Limited local reset to guest-local data and hardened settings bootstrap

Adjusted the local reset/testing path so it clears only guest-local routine/streak state instead of wiping signed-in streak caches. Also prevented Home settings bootstrap from overwriting routine-time or notification edits made before the bootstrap response returns.

**Files Created/Modified**:
- `Unstoppable/StreakManager.swift` - limited `clearLocalTestingState()` to guest-local and legacy unscoped keys
- `Unstoppable/HomeView.swift` - guarded bootstrap settings assignment with session-local edit tracking

---

## Key Results

Guest and signed-in users now keep separate local routine/onboarding state on the same device, and restored task completion survives Stats tab navigation after login/logout cycles.

| Metric | Before | After |
|--------|--------|-------|
| Guest vs signed-in local routine flags | Mixed via shared keys | Scoped by active auth context |
| Local reset impact on signed-in streak cache | Signed-in cache could be wiped | Guest-local only |
| Auth transition behavior | Guest draft data could be flushed into signed-in account | No automatic guest merge |
| Restored task checks after Home -> Stats -> Home | Could disappear after login/restore | Rehydrated from stable completion state |
| Home settings bootstrap after local edit | Late bootstrap could overwrite local toggle/time edit | Local edit wins for current session |

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Keep fixes surgical and app-side | The reproduced bugs were local-state and hydration issues, not a UI redesign or backend contract change |
| Use auth-scoped local keys rather than one-off conditions | Centralizing scope in `StreakManager` reduced repeat bugs across streaks, routine flags, and draft state |
| Hydrate completion into `StreakManager`, not only the UI | The Home view was reapplying completion from manager state on return, so the manager had to own the restored truth |
| Prevent automatic guest-to-account promotion | If guest upgrade is needed later, it should be an explicit flow rather than a side effect of sign-in |

---

## Verification

The session included repeated build and simulator validation after each fix, plus user-driven runtime checks that confirmed the checkbox/state regressions during auth and tab navigation.

```bash
# Baseline
git status --short
git branch --show-current

# Verification commands used
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
OPEN_SIMULATOR_APP=1 ./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] Captured baseline repo state on `agentic-dev-v1`
- [x] Verified direct `xcodebuild` succeeds after the final patch set
- [x] Verified simulator build/install/launch on `iPhone 17 Pro`
- [x] User confirmed the Home -> Stats -> Home task restore bug is resolved after the final completion hydration fix
- [x] User confirmed guest/auth routine separation is working better after the auth-scoping fixes

---

## Key Learnings

1. **Hydration must update both UI state and singleton state**: Restoring checked tasks only in `HomeView` was not enough because the tab-return path reapplied completion from `StreakManager`.
2. **Auth-scoped local state needs to include flow flags**: Even when routine payloads are scoped, shared booleans like onboarding/routine-created flags can still leak guest state across accounts.
3. **Testing/reset utilities need explicit scope rules**: A generic local reset helper can silently destroy signed-in cached state unless it knows which keys are guest-only.

---

## Next Steps

- Manually re-test Google and Apple auth flows if backend/bootstrap payload structure changes again.
- Watch other bootstrap consumers for the same late-response overwrite pattern used by the settings fix.

---

## Related Documents

- `ROUTINE_STATS_USER_SCOPING_20260307.md` - earlier app log from the same day covering the initial streak/routine stats scoping fix
- `HOME_SETTINGS_BOOTSTRAP_SYNC_20260222.md` - prior Home bootstrap/settings synchronization work
