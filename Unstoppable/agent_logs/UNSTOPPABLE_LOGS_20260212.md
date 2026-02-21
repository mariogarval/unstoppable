# App Networking and Sync Rollout

**Date**: 2026-02-12
**Status**: Complete
**Branch**: `add-flow-docs`
**Author**: Codex (GPT-5)

---

## Summary

Implemented the app networking foundation, wired endpoint sync across onboarding/home/progress flows, fixed auth and URL mismatches, and revalidated simulator behavior after each integration pass.

---

## Problem Statement

The app needed to transition from local-only state writes to backend-synced flows while preserving onboarding/home UX continuity.

---

## Changes Made

### 1. Added networking layer and models

Created API client, request/response models, and sync service.

**Files Created/Modified**:
- `Unstoppable/Networking/APIClient.swift`
- `Unstoppable/Networking/Models.swift`
- `Unstoppable/Sync/UserDataSyncService.swift`
- `Unstoppable.xcodeproj/project.pbxproj`

### 2. Integrated sync into app flows

Wired profile/routine/progress/bootstrap calls across onboarding and home screens.

**Files Created/Modified**:
- `Unstoppable/StreakManager.swift`
- `Unstoppable/WelcomeView.swift`
- `Unstoppable/NicknameView.swift`
- `Unstoppable/HomeView.swift`
- `Unstoppable/onboarding/AgeGroupView.swift`
- `Unstoppable/onboarding/GenderSelectionView.swift`
- `Unstoppable/onboarding/NotificationPermissionView.swift`
- `Unstoppable/onboarding/TermsSheetView.swift`
- `Unstoppable/onboarding/PaywallView.swift`

### 3. Resolved auth and endpoint mismatches

Adjusted debug auth fallback behavior and aligned dev backend URL to active Cloud Run service.

**Files Created/Modified**:
- `Unstoppable/Networking/APIClient.swift`
- `Unstoppable.xcodeproj/project.pbxproj`

### 4. Updated docs and scoped session memory

Documented runtime behavior and maintained scoped app session log/index.

**Files Created/Modified**:
- `README.md`
- `Unstoppable/agent_logs/UNSTOPPABLE_LOGS_20260212.md`
- `Unstoppable/agent_logs/__AGENT_INDEX.md`

---

## Key Results

- Core networking layer is integrated in app target.
- Endpoint wiring covers onboarding profile sync, routine sync, and daily progress sync.
- First successful app-originated API call was confirmed in simulator logs (`response_status=200`).
- Build and launch validations passed after integration updates.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Keep local persistence plus async backend sync | Enables migration without blocking existing UX on network availability. |
| Use Debug `X-User-Id` fallback during rollout | Allows fast validation before full bearer-token-only enforcement. |
| Store paywall selection in profile payload | Preserves onboarding conversion context without new endpoint complexity. |

---

## Verification

```bash
mkdir -p .build/ModuleCache && swiftc -module-cache-path .build/ModuleCache -typecheck Unstoppable/Networking/APIClient.swift Unstoppable/Networking/Models.swift Unstoppable/Sync/UserDataSyncService.swift
./scripts/run_ios_sim.sh "iPhone 17 Pro"
xcrun simctl spawn booted log stream --level debug --predicate 'process == "Unstoppable"'
xcrun simctl spawn booted log show --last 15m --style compact --predicate 'process == "Unstoppable" && eventMessage CONTAINS "response_status="' | tail -n 20
rg -n "fetchBootstrap|syncUserProfile|syncAgeGroup|syncGender|syncNotificationsEnabled|syncTermsAccepted|syncRoutineSnapshot|RoutineUpsertRequest|DailyProgressUpsertRequest" Unstoppable
```

- [x] Networking components compiled and wired into target.
- [x] Simulator build/install/launch succeeded.
- [x] Runtime logs confirmed successful app-to-backend response.

---

## Next Steps

- Add retry/offline reconciliation strategy if sync reliability requirements increase.
- Continue tightening bearer-token-only validation as auth rollout matures.

---

## Related Documents

- `backend/agent_logs/CLOUD_SETUP_20260212.md` - backend endpoint setup and deployment baseline.
- `Unstoppable/agent_logs/BUNDLE_ID_MIGRATION_20260217.md` - later auth config alignment.
