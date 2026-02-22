# Apple Auth Implementation Plan (iOS + Firebase + Existing Backend)

Last updated: 2026-02-21  
Owner: `Unstoppable` app team  
Status: In Progress (implementation complete; runtime verification pending)

## Purpose
Implement `Continue with Apple` in iOS using Firebase Auth, aligned with the existing Google/Firebase auth architecture and backend bearer-token mode.

## Confirmed Decisions
1. Auth provider path: Firebase Auth (same architecture as Google).
2. Account strategy: link accounts by email when possible.
3. Backend token model: continue relying on Firebase-issued ID tokens (`Authorization: Bearer <Firebase ID token>`).
4. Compliance scope: iOS App Store compliance only.

## Clarifications Captured (2026-02-21)
1. The Apple auth flow should mirror Google flow architecture (Firebase-managed session and token issuance).
2. Account linking should use email-matching strategy and avoid duplicate user creation when Apple collides with existing Google accounts.
3. Firebase Console Apple credentials (`Service ID`, `Team ID`, `Key ID`, `.p8`) can appear optional for Apple-platform-only sign-in, but were treated as recommended setup for completeness and future token revocation/account-management support.
4. Google credentials are not reusable for Apple provider setup; Apple requires Apple-specific key material.

## Execution Record (2026-02-20 to 2026-02-21)

### Completed steps
- `AA-00`, `AA-00A`: Baseline state captured (`git status --short`, current branch).
- `AA-01`: Working branch created: `codex/apple-auth-firebase`.
- `AA-02`: Baseline iOS build succeeded on `iPhone 17 Pro`.
- `AA-10` (manual): Sign in with Apple capability enabled for bundle `app.unstoppable.unstoppable` and entitlements wired.
- `AA-11` (manual): Apple provider enabled in Firebase Authentication.
- `AA-12` (manual): Apple/Firebase redirect/domain configuration verified in Firebase Console.
- `AA-20` to `AA-24`: iOS implementation completed in app code.
- `AA-30`, `AA-30A`: Static checks and simulator builds succeeded.
- `AA-31` (build/install/launch portion): `./scripts/run_ios_sim.sh "iPhone 17 Pro"` succeeded with app launch.
- `AA-41`: docs updated to reflect Apple auth support and runbook cross-reference.

### Pending steps
- `AA-31` manual matrix:
  - New Apple sign-in flow validation.
  - Returning user/session restore validation.
  - Apple + existing Google email linking validation.
  - Sign-out return-to-`WelcomeView` validation.
- `AA-32` backend validation:
  - Verify protected endpoint call with Firebase bearer token after Apple sign-in.
- `AA-40` App Store parity final checklist signoff.

### Key implementation files changed
- `Unstoppable/Auth/AuthSessionManager.swift`
- `Unstoppable/WelcomeView.swift`
- `Unstoppable/Unstoppable.entitlements`
- `Unstoppable.xcodeproj/project.pbxproj`
- `README.md`
- `GOOGLE_AUTH_PLAN.md`

### Executed terminal commands (representative)
```bash
git status --short
git branch --show-current
git checkout -b codex/apple-auth-firebase
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
./scripts/run_ios_sim.sh "iPhone 17 Pro"
rg -n "SignInWithAppleButton|apple.com|ASAuthorization|nonce|accountExistsWithDifferentCredential" Unstoppable -S
xcrun simctl spawn booted log show --last 2m --style compact --predicate 'process == "Unstoppable"'
```

## Outcomes
- `Continue with Apple` works from `Unstoppable/WelcomeView.swift`.
- Successful Apple sign-in uses Firebase Auth session and existing bearer token provider flow.
- Existing Google account users can link Apple credentials when emails match.
- Sign-out/session-restore behavior remains unchanged (still managed by `AuthSessionManager`).
- App Store parity requirement is satisfied when third-party auth is present.

## Scope
- In scope:
  - Apple provider setup in Firebase + Apple Developer prerequisites.
  - iOS Sign in with Apple request/completion wiring in existing welcome flow.
  - Firebase credential exchange and account-linking behavior.
  - Validation matrix and rollout checklist.
- Out of scope:
  - Non-iOS client implementations.
  - Backend-native Apple token validation (not needed for current architecture).

## Reusable Inputs (Set First)
```bash
export APP_NAME="Unstoppable"
export IOS_BUNDLE_ID="app.unstoppable.unstoppable"
export XCODE_PROJECT_PATH="/Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj"
export XCODE_SCHEME="Unstoppable"
export SIMULATOR_NAME="iPhone 17 Pro"
export FIREBASE_PROJECT_ID="unstoppable-app-dev"
export API_BASE_URL_DEV="https://unstoppable-api-1094359674860.us-central1.run.app"
```

## Execution Documentation Standard
Use AA step IDs throughout the plan.

Rules:
- Run commands directly (no shell logging wrapper required).
- Record manual console actions as `ACTION [AA-XX]: ...` notes only when documentation is requested.

## Phase Plan (With Step IDs)

## Phase 0: Baseline and Branch

### AA-00: Capture baseline
```bash
git -C /Users/luisgalvez/Projects/unstoppable status --short
git -C /Users/luisgalvez/Projects/unstoppable branch --show-current
```
Acceptance:
- Starting state and branch logged.

### AA-01: Create working branch
```bash
git -C /Users/luisgalvez/Projects/unstoppable checkout -b codex/apple-auth-firebase
```
Acceptance:
- New branch created and active.

### AA-02: Baseline build
```bash
xcodebuild -project "$XCODE_PROJECT_PATH" -scheme "$XCODE_SCHEME" -configuration Debug -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" build
```
Acceptance:
- Baseline build succeeds before auth changes.

## Phase 1: Provider and Console Setup

### AA-10: Enable Sign in with Apple capability for app ID
Manual actions:
- Apple Developer portal: confirm `Sign in with Apple` capability on bundle ID `$IOS_BUNDLE_ID`.
- Xcode target signing/capabilities: add `Sign In with Apple` if missing.

Log example:
`ACTION [AA-10]: Verified Apple capability enabled for $IOS_BUNDLE_ID in Apple Developer + Xcode.`
Acceptance:
- Capability enabled at both provisioning and target levels.

### AA-11: Enable Apple provider in Firebase Authentication
Manual actions:
- Firebase Console -> Authentication -> Sign-in method -> Apple provider -> enable.
- Configure required Apple details (Team ID, Key ID, private key, Service ID) if not already configured.

Log example:
`ACTION [AA-11]: Enabled Apple provider in Firebase Auth for $FIREBASE_PROJECT_ID.`
Acceptance:
- Apple provider shows enabled in Firebase Auth.

### AA-12: Verify auth domain/redirect config
Manual checks:
- Confirm Firebase auth domain is configured for iOS flow.
- Confirm Apple/Firebase redirect path consistency (Firebase handler endpoint).

Log example:
`ACTION [AA-12]: Verified Apple/Firebase redirect and auth domain configuration.`
Acceptance:
- No provider-misconfiguration warnings in Firebase console.

## Phase 2: iOS App Implementation

Expected files:
- `Unstoppable/WelcomeView.swift`
- `Unstoppable/Auth/AuthSessionManager.swift`

### AA-20: Add Apple sign-in request scopes + nonce wiring
Implementation:
- In `WelcomeView`, configure Apple request with nonce and scopes (`.fullName`, `.email` as needed).
- Pass completion result into `AuthSessionManager`.

Acceptance:
- Apple authorization request includes hashed nonce; callback result is routed to auth manager.

### AA-21: Add Firebase Apple credential sign-in path
Implementation in `AuthSessionManager`:
- Generate/store raw nonce.
- Convert `ASAuthorizationAppleIDCredential.identityToken` to string.
- Build Firebase credential with `OAuthProvider.credential(providerID: .apple, idToken: ..., rawNonce: ...)`.
- Call `Auth.auth().signIn(with: credential)`.
- Keep existing post-auth behavior:
  - `RevenueCatManager.shared.logIn(appUserID: user.uid)`
  - `syncService.setAuthMode(makeBearerMode())`

Acceptance:
- Successful Apple sign-in produces Firebase-authenticated user and bearer-token API mode.

### AA-22: Implement account linking by email
Implementation:
- Handle `AuthErrorCode.accountExistsWithDifferentCredential` for Apple credential attempts.
- Fetch sign-in methods for returned email.
- If existing method is `google.com`, prompt user to sign in with Google first, then link pending Apple credential to current Firebase user.
- After linking, persist Apple as provider for future sign-ins.

Acceptance:
- Same-email Google account can be linked to Apple credential without creating duplicate account.

### AA-23: Handle Apple private relay and missing-email edge cases
Implementation:
- If Apple returns relay email (`privaterelay.appleid.com`) or no email on subsequent sign-ins, avoid destructive account merge assumptions.
- Show clear fallback message to sign in with existing provider and link accounts manually.

Acceptance:
- No accidental account duplication/override from hidden or missing Apple email values.

### AA-24: Wire WelcomeView UX states and routing
Implementation:
- Add `isAppleSigningIn` loading/disable state.
- Reuse existing `authErrorMessage` surface.
- On success, call same routing path as Google (`bootstrapIfNeeded(force: true)` then `routeAuthenticatedUser`).

Acceptance:
- Apple sign-in UX behavior is consistent with Google flow and current onboarding routing.

## Phase 3: Verification and QA

### AA-30: Static checks and build
```bash
rg -n "SignInWithAppleButton|apple.com|ASAuthorization|nonce|accountExistsWithDifferentCredential" Unstoppable -S
xcodebuild -project "$XCODE_PROJECT_PATH" -scheme "$XCODE_SCHEME" -configuration Debug -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" build
```
Acceptance:
- Build succeeds and expected Apple auth hooks are present.

### AA-31: Runtime simulator/device validation
```bash
./scripts/run_ios_sim.sh "$SIMULATOR_NAME"
```
Manual matrix:
- New user signs in with Apple -> lands correctly (Nickname/Home based on bootstrap).
- Existing signed-out user signs in with Apple -> session restore works on relaunch.
- Existing Google account with same email -> linking path succeeds.
- Sign out -> app returns to `WelcomeView`.

Log example:
`ACTION [AA-31]: Completed Apple sign-in matrix: new user, returning user, Google-link case, sign-out routing.`
Acceptance:
- All matrix scenarios pass without auth regressions.

### AA-32: Backend bearer-token validation (unchanged contract)
Manual/API check:
- After Apple sign-in, call a protected endpoint and verify `Authorization: Bearer <Firebase ID token>` works exactly as Google flow.

Acceptance:
- Backend accepts Firebase token from Apple-authenticated session with no backend changes required.

## Phase 4: Rollout and Compliance

### AA-40: App Store parity checklist
Checklist:
- If Google/third-party sign-in is offered, Apple sign-in is visible and functional on iOS.
- Apple button placement and prominence are not materially inferior.
- Terms/privacy messaging remains accurate.

Acceptance:
- iOS auth experience aligns with App Store Sign in with Apple expectations.

### AA-41: Release notes and docs updates
Update:
- `README.md` auth section with Apple support note.
- `GOOGLE_AUTH_PLAN.md` cross-reference to this Apple plan (optional but recommended).

Acceptance:
- Runbooks and project docs reflect current auth providers.

## Rollback Plan
- Keep implementation isolated to Apple auth paths in `WelcomeView` + `AuthSessionManager`.
- If critical issue appears before release, temporarily disable Apple button action (or hide behind local feature flag) while preserving Google sign-in path.
- Re-run `AA-30A` and `AA-31` to confirm no regression in Google auth and routing.

## Risks and Mitigations
1. Email linking ambiguity due to Apple private relay.
- Mitigation: only auto-link when verified same email confidence exists; otherwise require explicit provider sign-in then link.

2. Nonce handling errors causing Firebase Apple sign-in failures.
- Mitigation: centralize nonce generation/hash logic in `AuthSessionManager` and add explicit error logs in Debug builds.

3. UX regression in welcome routing.
- Mitigation: reuse existing Google success path and existing `routeAuthenticatedUser(using:)` logic.

## Definition of Done
- Apple sign-in succeeds via Firebase on iOS.
- Bearer token API mode works post-Apple sign-in.
- Account linking by email works for Google-existing users where email match is valid.
- Sign-out and session restore behaviors remain correct.
- Build + simulator validation pass and are documented with AA step IDs.
