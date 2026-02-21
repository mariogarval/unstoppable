# Sign-Out Routing

**Date**: 2026-02-12
**Status**: Complete
**Branch**: `codex/google-auth-setup`
**Author**: Codex (GPT-5)

---

## Summary

Implemented settings sign-out flow and fixed post-sign-out navigation so users reliably return to `WelcomeView` rather than re-entering onboarding/paywall stack.

---

## Problem Statement

The app lacked a complete sign-out UX path and had a routing regression where signed-out users could land in the wrong navigation state.

---

## Changes Made

### 1. Added sign-out controls in settings

Introduced a dedicated account sign-out action with loading and error handling.

**Files Created/Modified**:
- `Unstoppable/HomeView.swift`

### 2. Wired sign-out to auth teardown

Connected settings action to `AuthSessionManager.shared.signOut()`.

**Files Created/Modified**:
- `Unstoppable/HomeView.swift`
- `Unstoppable/Auth/AuthSessionManager.swift` (integration usage context)

### 3. Fixed post-sign-out route target

Replaced simple dismiss behavior with root reset to `WelcomeView` plus fallback handling.

**Files Created/Modified**:
- `Unstoppable/HomeView.swift`

---

## Key Results

- Settings sign-out is functional and user-visible.
- Post-sign-out destination now consistently resets to `WelcomeView`.
- Build and simulator launch checks passed after routing fix.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Keep sign-out action in existing Settings structure | Preserves app UI continuity and avoids navigation redesign. |
| Use root-view reset after sign-out | Prevents exposing underlying onboarding/paywall stack in navigation history. |
| Keep dismiss fallback | Handles edge cases where window lookup is unavailable. |

---

## Verification

```bash
rg -n "struct .*Settings|SettingsTab|signOut|HomeView|WelcomeView" Unstoppable
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
rg -n "routeToWelcomeAfterSignOut|handleSignOut|AuthSessionManager\.shared\.signOut\(\)" /Users/luisgalvez/Projects/unstoppable/Unstoppable/HomeView.swift
```

- [x] Sign-out UI/action implemented.
- [x] Auth session teardown wired.
- [x] Post-sign-out route reset verified in code and build/launch checks.

---

## Next Steps

- Re-verify sign-out destination whenever onboarding/auth route logic changes.

---

## Related Documents

- `Unstoppable/agent_logs/PROFILE_COMPLETION_ROUTING_20260221.md` - later auth route gating updates.
