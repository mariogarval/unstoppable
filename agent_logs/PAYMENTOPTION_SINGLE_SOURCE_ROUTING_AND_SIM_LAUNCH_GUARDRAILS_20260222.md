# paymentOption Single-Source Routing and Simulator Launch Guardrails

**Date**: 2026-02-22
**Status**: Code Complete
**Branch**: `codex/payments-revenuecat-plan`
**Author**: Codex (GPT-5)

---

## Summary

This session removed lingering profile/payment coupling and finalized routing behavior when payment selection is missing. It also hardened simulator execution workflow so build verification always installs/launches the latest binary, and clarified AGENTS guidance to prevent build-only handoffs.

---

## Problem Statement

The app and backend still had edge cases where `paymentOption` behavior was mixed with profile semantics, producing incorrect routing and unnecessary profile timestamp updates. Separately, build checks were sometimes run without ensuring the latest build artifact was installed/launched in Simulator, causing stale-binary validation.

---

## Changes Made

### 1. Enforced canonical paymentOption ownership in backend subscription doc

Removed profile-mirror fallback/write behavior and kept `paymentOption` authoritative in `users/{uid}/payments/subscription`.

**Files Modified**:
- `backend/api/src/app.py`
  - Completion logic now resolves `paymentOption` from subscription only.
  - Removed profile mirror backfills from snapshot and webhook paths.
  - Updated `/v1/user/profile` handling to avoid profile writes when payload only carries `paymentOption`.
- `backend/api/scripts/reset_user_payments.py`
  - Removed profile `paymentOption` reset behavior.
- `backend/api/scripts/check_user_payments.py`
  - Removed profile mirror-focused output.
- `backend/api/README.md`
- `backend/api/API_RUNBOOK.md`
  - Updated docs to reflect subscription-only ownership.

### 2. Split auth routing: profile completion vs payment selection

Routing now distinguishes between profile-required fields and payment selection.

**Files Modified**:
- `Unstoppable/WelcomeView.swift`
  - Added separate navigation path to paywall when profile fields are complete but `paymentOption` is missing.
  - Uses `profileCompletion.missingRequiredFields` when present, with `paymentOption` evaluated separately.

### 3. Paywall dismiss behavior updated

Top-right dismiss no longer writes `paymentOption`.

**Files Modified**:
- `Unstoppable/onboarding/PaywallView.swift`
  - `x` button now routes directly to `HomeView` without profile sync.

### 4. Simulator launch workflow hardened for latest-binary usage

Updated launcher script to install the newest built app artifact by timestamp.

**Files Modified**:
- `scripts/run_ios_sim.sh`
  - Added `find_latest_built_app()` to select latest build from repo `.build` and Xcode `DerivedData`.
  - Install/launch now uses newest artifact rather than fixed-path assumption.

### 5. AGENTS policy clarification

Added explicit rule to prevent build-only validation handoff.

**Files Modified**:
- `AGENTS.md`
  - Requires build checks to be followed by simulator install/launch in the same workflow.

---

## Key Results

- `paymentOption` behavior is now consistent with single-source ownership in subscription documents.
- Profile `updatedAt` is no longer bumped by paywall selection-only payloads.
- Authenticated users with complete profile but missing payment selection now route to paywall (not nickname flow).
- Paywall dismiss (`x`) goes straight to home without writing `paymentOption`.
- Simulator workflow now reduces stale-binary validation risk by always launching newest build artifact.

---

## Verification

```bash
# Backend syntax checks
python3 -m py_compile backend/api/src/app.py backend/api/scripts/reset_user_payments.py backend/api/scripts/check_user_payments.py

# API deploy
backend/api/deploy_cloud_run.sh unstoppable-app-dev

# Build + install + launch on simulator
OPEN_SIMULATOR_APP=1 ./scripts/run_ios_sim.sh "iPhone 17 Pro"

# Relaunch without rebuild when needed
xcrun simctl terminate booted app.unstoppable.unstoppable || true
xcrun simctl launch booted app.unstoppable.unstoppable
```

- [x] Backend compile checks passed.
- [x] Cloud Run deployed (`unstoppable-api-00012-xmk`) and serving traffic.
- [x] Simulator build/install/launch succeeded on `iPhone 17 Pro`.
- [x] Paywall dismiss flow changed to no-write route to `HomeView`.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Keep `paymentOption` canonical in subscription doc only | Removes profile/payment duplication and drift risk. |
| Route missing-profile and missing-payment separately | Supports profile flow first, then paywall-only gating. |
| Require install/launch after build checks | Avoids stale simulator binaries during validation. |

---

## Related Documents

- `agent_logs/PAYMENTS_FAKE_SUBSCRIPTION_AND_CANONICAL_PAYMENT_OPTION_20260221.md` - previous canonicalization stage with profile mirroring compatibility.
- `agent_logs/REVENUECAT_OFFERINGS_BLOCKER_AND_PAYWALL_RETRY_20260221.md` - paywall runtime context and simulator validation history.
