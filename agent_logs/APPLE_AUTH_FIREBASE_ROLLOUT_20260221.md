# Apple Auth Firebase Rollout

**Date**: 2026-02-21
**Status**: In Progress
**Branch**: `codex/apple-auth-firebase`
**Author**: Codex (GPT-5)

---

## Summary

This session implemented `Continue with Apple` using Firebase Auth in the existing iOS auth architecture. The flow now supports nonce-based Apple credential exchange, Firebase session setup, and email-based account-link handling when Apple collides with existing Google accounts. Build and simulator launch validation passed, with manual runtime matrix and backend token verification still pending.

---

## Problem Statement

The app already exposed a Sign in with Apple button in `WelcomeView`, but it had no integrated auth logic. The objective was to complete Apple sign-in under Firebase Auth, keep parity with the existing Google + bearer-token backend flow, and preserve current restore/sign-out navigation behavior.

---

## Changes Made

### 1. Implemented Apple auth flow in session manager

Added Apple request nonce handling, Firebase Apple credential sign-in, and account-linking scaffolding for existing Google accounts.

**Files Created/Modified**:
- `Unstoppable/Auth/AuthSessionManager.swift` - Apple nonce generation/hashing, Apple credential exchange, account-collision handling, pending-link completion after Google sign-in, and user-facing auth errors.

### 2. Wired WelcomeView Apple action to real auth flow

Connected `SignInWithAppleButton` request/completion handlers to `AuthSessionManager`, added Apple loading state, and aligned success routing with Google flow.

**Files Created/Modified**:
- `Unstoppable/WelcomeView.swift` - request config, completion handler, `isAppleSigningIn`, unified disabled states, and routed post-auth bootstrap/navigation.

### 3. Enabled capability + entitlements in project

Validated that Xcode capability changes are reflected in project/entitlements for Sign in with Apple.

**Files Created/Modified**:
- `Unstoppable/Unstoppable.entitlements` - Apple sign-in entitlement key.
- `Unstoppable.xcodeproj/project.pbxproj` - `CODE_SIGN_ENTITLEMENTS` target wiring.

### 4. Added and updated runbook/docs

Created Apple auth implementation runbook and updated repository docs to reflect Apple + Google auth state.

**Files Created/Modified**:
- `APPLE_AUTH_PLAN.md` - full AA-step rollout plan + execution record and clarifications.
- `README.md` - auth section updated for Apple+Google support and debug expectations.
- `GOOGLE_AUTH_PLAN.md` - cross-reference to `APPLE_AUTH_PLAN.md`.

---

## Key Results

- Apple auth implementation is complete in code path (`WelcomeView` + `AuthSessionManager`).
- Simulator builds and script-based launch validations succeeded after implementation.
- Project now has explicit Apple auth runbook + updated auth docs.
- Manual runtime matrix and backend bearer-token verification remain open.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Use Firebase Auth for Apple sign-in | Keeps auth architecture consistent with existing Google flow. |
| Link by email when Apple collides with Google account | Prevents duplicate user creation and preserves account continuity. |
| Keep backend contract unchanged (`Authorization: Bearer <Firebase ID token>`) | Avoids backend auth model churn and reuses existing protected endpoint behavior. |
| Treat Firebase Apple credential fields as recommended setup | Supports more complete provider config and future revocation/account management scenarios. |

---

## Verification

```bash
git status --short
git branch --show-current
git checkout -b codex/apple-auth-firebase
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
rg -n "SignInWithAppleButton|apple.com|ASAuthorization|nonce|accountExistsWithDifferentCredential" Unstoppable -S
xcrun simctl spawn booted log show --last 2m --style compact --predicate 'process == "Unstoppable"'
```

- [x] Baseline and post-change simulator builds succeeded.
- [x] Scripted simulator install/launch succeeded (`app.unstoppable.unstoppable` launched).
- [x] Apple entitlement wiring verified in project files.
- [ ] Manual Apple sign-in test matrix completed (new user, returning user, link collision, sign-out route).
- [ ] Backend endpoint verification completed with Apple-auth Firebase bearer token.

---

## Next Steps

- Execute AA-31 manual matrix on simulator/device:
  - New Apple sign-in.
  - Returning session restore.
  - Apple + existing Google email link path.
  - Sign-out returns to `WelcomeView`.
- Execute AA-32 backend curl validation using Firebase ID token post-Apple sign-in.
- Mark AA-40 App Store parity checklist complete after successful runtime validations.

---

## Related Documents

- `APPLE_AUTH_PLAN.md` - active Apple auth runbook and step tracking.
- `GOOGLE_AUTH_PLAN.md` - existing Google auth runbook.
- `README.md` - current auth/runtime behavior reference.
