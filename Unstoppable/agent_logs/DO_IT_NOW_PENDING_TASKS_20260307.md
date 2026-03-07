# Do It Now Pending Tasks

**Date**: 2026-03-07
**Status**: Complete
**Branch**: `agentic-dev-v1`
**Author**: Codex (GPT-5)

---

## Summary

Updated the Home routine launch flow so `Do It Now` only opens tasks that are still unchecked for the current day. The change stays app-side, reuses the existing per-day completion state, and prevents already completed tasks from reappearing in the timer flow.

---

## Problem Statement

The `Do It Now` flow was launching the full routine task list even when some tasks were already marked complete for the day. That created redundant steps in the timer flow and did not match the current-day progress shown in Home.

---

## Changes Made

### 1. Filtered timer input to pending tasks only

Added a `pendingTasks` computed property in `HomeView` and passed that filtered list into `RoutineTimerView` instead of the full `tasks` array.

**Files Created/Modified**:
- `Unstoppable/HomeView.swift` - added pending-task filtering and routed `RoutineTimerView` through the filtered list

### 2. Guarded the CTA when the day is already complete

Kept the existing `Do It Now` button in place, but disabled and dimmed it when no unchecked tasks remain for the day so the flow cannot open with an empty task list.

**Files Created/Modified**:
- `Unstoppable/HomeView.swift` - disabled `Do It Now` when `pendingTasks` is empty

### 3. Documented the updated flow

Added a short README note so the current Home routine behavior is captured in the runbook.

**Files Created/Modified**:
- `README.md` - documented that `Do It Now` launches only unchecked tasks for the current day

---

## Key Results

The Home routine flow now matches visible daily progress: completed tasks stay complete in Home and are excluded from the timer sequence.

| Metric | Before | After |
|--------|--------|-------|
| `Do It Now` input | Full routine task list | Only unchecked tasks |
| Already-completed task behavior | Reappeared in timer flow | Excluded from timer flow |
| All-done CTA behavior | Could open empty/incorrect flow risk | Button disabled when no pending tasks remain |

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Filter in `HomeView` instead of changing `RoutineTimerView` internals | `HomeView` already owns the per-day completion state and the handoff into the timer flow |
| Preserve the current button and styling | The request was behavioral, not a redesign |
| Keep README update minimal | Behavior changed in a user-facing flow and should be reflected in the local runbook without expanding scope |

---

## Verification

Validation used the repo-required simulator launch workflow after the change was applied.

```bash
# Baseline
git status --short
git branch --show-current

# Review
git diff -- /Users/luisgalvez/Projects/unstoppable/Unstoppable/HomeView.swift /Users/luisgalvez/Projects/unstoppable/README.md

# Verification commands used
OPEN_SIMULATOR_APP=1 ./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] Captured baseline repo state on `agentic-dev-v1`
- [x] Confirmed the implementation only touches the Home routine flow and README
- [x] Parallel review worker reported no correctness findings on the changed path
- [x] Verified simulator build/install/launch on `iPhone 17 Pro`
- [x] Confirmed build result `BUILD SUCCEEDED`
- [x] Confirmed app launch result for bundle id `app.unstoppable.unstoppable`

---

## Next Steps

- Manually smoke-test the partially completed routine case in Simulator to confirm only remaining tasks appear after restore/hydration.
- Decide whether the disabled all-done `Do It Now` state needs explicit helper copy in a future UX pass.

---

## Related Documents

- `HOME_ROUTINE_STATE_ISOLATION_20260307.md` - earlier Home routine state and completion hydration fixes from the same day

