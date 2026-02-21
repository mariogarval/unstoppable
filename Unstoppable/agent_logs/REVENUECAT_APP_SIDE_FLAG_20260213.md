# RevenueCat App-Side Flag

**Date**: 2026-02-13
**Status**: Complete
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

Introduced a runtime feature flag that keeps RevenueCat app-side behavior as default while preserving optional backend subscription snapshot sync.

---

## Problem Statement

Payments rollout required a safe default that did not force backend availability in all development/test environments.

---

## Changes Made

### 1. Added backend-sync feature flag

Added runtime gating for subscription snapshot sync through configuration.

**Files Created/Modified**:
- `Unstoppable/Payments/RevenueCatManager.swift` - backend sync calls gated.
- `Unstoppable/Info.plist` - runtime config key wiring.
- `Unstoppable/Config/RevenueCat.xcconfig` - default value wiring.
- `Unstoppable/Config/Secrets.local.xcconfig.example` - local override guidance.

### 2. Updated project docs and scoped memory

Documented new default behavior and migrated this session entry under scoped app `agent_logs`.

**Files Created/Modified**:
- `README.md`
- `PAYMENTS_PLAN.md`
- `Unstoppable/agent_logs/REVENUECAT_APP_SIDE_FLAG_20260213.md`
- `Unstoppable/agent_logs/__AGENT_INDEX.md`

---

## Key Results

- Default behavior keeps payments app-side without requiring backend payment endpoints.
- Backend snapshot sync remains available when explicitly enabled.
- Validation build passed on simulator destination.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Default `REVENUECAT_ENABLE_BACKEND_SYNC=NO` | Minimizes rollout risk and environment coupling. |
| Keep sync code present but disabled by default | Enables controlled activation without reimplementation. |
| Use config-driven toggle | Keeps behavior transparent and environment-specific. |

---

## Verification

```bash
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
git status --short
rg -n "RevenueCat|payments|snapshot|REVENUECAT" README.md PAYMENTS_PLAN.md Unstoppable/Config/Secrets.local.xcconfig
```

- [x] Feature flag added and wired through runtime config.
- [x] Build validation passed.
- [x] Docs updated with new default behavior.

---

## Next Steps

- Enable backend sync only in environments that need subscription snapshot persistence.

---

## Related Documents

- `Unstoppable/agent_logs/REVENUECAT_PHASE2_20260212.md` - snapshot sync implementation details.
- `backend/agent_logs/REVENUECAT_BACKEND_PHASE3_20260212.md` - backend subscription endpoints/webhook work.
