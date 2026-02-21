# Profile Completion Routing Alignment

**Date**: 2026-02-21
**Status**: Complete
**Branch**: `codex/apple-auth-firebase`
**Author**: Codex (GPT-5)

---

## Summary

Updated app bootstrap decoding and welcome-route gating to use explicit profile completion semantics, ensuring authenticated users with incomplete required fields are routed through onboarding.

---

## Problem Statement

Route gating based only on `paymentOption` allowed incomplete profiles to be treated as onboarded.

---

## Changes Made

### 1. Expanded bootstrap response model for completion metadata

Added explicit completion fields to the app network model.

**Files Created/Modified**:
- `Unstoppable/Networking/Models.swift` - added `isProfileComplete` and `profileCompletion` models.

### 2. Updated authenticated routing logic in welcome flow

Replaced single-field onboarding check with completion-based logic and safe fallback checks.

**Files Created/Modified**:
- `Unstoppable/WelcomeView.swift` - switched to `isProfileComplete`-driven routing and fallback validation.

### 3. Updated docs and scoped memory

Documented completion-driven routing behavior and migrated this session entry into scoped `agent_logs`.

**Files Created/Modified**:
- `README.md` - updated auth/bootstrap contract notes.
- `Unstoppable/agent_logs/PROFILE_COMPLETION_ROUTING_20260221.md`
- `Unstoppable/agent_logs/__AGENT_INDEX.md`

---

## Key Results

- Authenticated users now route to onboarding when required profile data is incomplete.
- Completed profiles continue routing directly to `HomeView`.
- Build and simulator launch checks passed.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Prefer backend-provided completion truth | Keeps completion logic centralized in backend contract. |
| Keep app-side fallback completion check | Preserves safe behavior if backend payloads are temporarily mixed during rollout. |
| Keep onboarding entry at `NicknameView` | Avoids changing view hierarchy during routing fix. |

---

## Verification

```bash
sed -n '1,360p' /Users/luisgalvez/Projects/unstoppable/Unstoppable/WelcomeView.swift
sed -n '1,220p' /Users/luisgalvez/Projects/unstoppable/Unstoppable/Networking/Models.swift
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] Completion metadata decoding added to app model.
- [x] Welcome routing uses completion semantics.
- [x] Build and simulator launch passed.

---

## Next Steps

- Validate with real Google/Apple accounts that same-email auth + completion routing behaves as expected across sign-in, relaunch, and sign-out cycles.

---

## Related Documents

- `backend/agent_logs/IDENTITY_CANONICALIZATION_PROFILE_COMPLETION_20260221.md` - backend producer of completion and canonical identity behavior.
- `agent_logs/APPLE_AUTH_FIREBASE_ROLLOUT_20260221.md` - app-level Apple auth rollout context.
