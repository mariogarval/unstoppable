# RevenueCat Email Attribute Sync

**Date**: 2026-02-22
**Status**: Complete
**Branch**: `codex/profile-email-sync`
**Author**: Codex (GPT-5)

---

## Summary

Added RevenueCat email attribute syncing so the authenticated Firebase user email is sent to RevenueCat whenever the app logs into RevenueCat with the canonical app user ID. This closes a data gap where purchases/subscription identity existed but email was not attached for attribution and support workflows.

---

## Problem Statement

RevenueCat identity login was wired with `appUserID`, but email was not propagated to RevenueCat attributes. As a result, user email could exist in Firebase and Firestore while still missing in RevenueCat customer attributes.

---

## Changes Made

### 1. RevenueCat manager API update

Extended RevenueCat login helper to accept optional email and sync it as a RevenueCat attribution attribute after successful `logIn`.

**Files Created/Modified**:
- `Unstoppable/Payments/RevenueCatManager.swift` - Added `email` parameter to `logIn(appUserID:email:)` and introduced `syncEmailAttribute(_:)` using `Purchases.shared.attribution.setEmail(...)`.

### 2. Auth session call-site updates

Passed Firebase user email through both restore-session and fresh-auth paths so RevenueCat email sync happens consistently.

**Files Created/Modified**:
- `Unstoppable/Auth/AuthSessionManager.swift` - Updated RevenueCat login calls in `restoreSessionIfPossible()` and `applyAuthenticatedSession(for:)` to provide `currentUser.email`/`user.email`.

---

## Key Results

- RevenueCat login now carries both stable user ID and normalized email attribute.
- Email sync executes in both session restore and interactive sign-in paths.
- iOS simulator build/install/launch validated after code changes.

| Metric | Before | After |
|--------|--------|-------|
| RevenueCat email attribute sync | Not implemented | Implemented |
| RevenueCat login call sites with email | 0 | 2 |

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Sync email immediately after successful `Purchases.logIn` | Ensures RevenueCat identity context is set before writing customer attribute |
| Keep email optional in manager API | Avoids forcing placeholder values when Firebase user email is absent |

---

## Verification

```bash
# Verification commands used
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
OPEN_SIMULATOR_APP=1 ./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

- [x] Simulator build succeeds after RevenueCat email sync changes
- [x] App installs and launches on `iPhone 17 Pro` with latest binary
- [ ] Runtime RevenueCat dashboard attribute inspection in sandbox account

---

## Next Steps

- Validate one end-to-end login in sandbox and confirm email appears in RevenueCat customer profile attributes.
- If needed, add lightweight debug logging around attribute sync success/failure for short-term rollout confidence.

---

## Related Documents

- `agent_logs/REVENUECAT_PAYMENTS_ROLLOUT_STATUS_20260217.md` - Broader RevenueCat implementation status and rollout context
- `agent_logs/PAYMENTOPTION_SINGLE_SOURCE_ROUTING_AND_SIM_LAUNCH_GUARDRAILS_20260222.md` - Prior same-day routing and simulator guardrails work
