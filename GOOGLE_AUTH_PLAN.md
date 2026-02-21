# Google Auth Implementation Plan (iOS + Firebase + Existing Backend)

Last updated: 2026-02-12  
Owner: `Unstoppable` app team  
Status: Executed (2026-02-12 rollout completed; GA-51 backend token curl still pending live token)

Apple auth companion runbook:
- `/Users/luisgalvez/Projects/unstoppable/APPLE_AUTH_PLAN.md`

## Purpose
Implement `Continue with Google` for iOS, authenticate with Firebase, and send Firebase ID tokens to backend endpoints using:

- `Authorization: Bearer <Firebase ID token>`

This document is written as a reusable runbook so it can be applied to other apps with minimal changes.

## Outcomes
- Google sign-in works from iOS app.
- Session persists across app launches.
- API calls are authenticated with Firebase ID tokens.
- Dev fallback auth remains available only in Debug (optional during rollout).
- Every action and command is logged for audit and reuse.

## Execution Record (2026-02-12)
Primary execution log:
- `/Users/luisgalvez/Projects/unstoppable/GOOGLE_AUTH_EXECUTION_20260212_180846.log`

Initial bootstrap log:
- `/Users/luisgalvez/Projects/unstoppable/GOOGLE_AUTH_EXECUTION_20260212_180830.log`

### Completed steps (GA IDs)
1. `GA-00`, `GA-00A` completed: repo status and active branch captured.
2. `GA-01` initially failed, then resolved via `GA-01D` with branch creation success on retry.
3. `GA-02` baseline build attempted; failed first due simulator service outage, later succeeded as `GA-02C`.
4. `GA-10`, `GA-10A` completed: active gcloud account/project confirmed.
5. `GA-11` completed manually in Firebase Console: Google provider enabled.
6. `GA-12`/`GA-12A` completed: `GoogleService-Info.plist` downloaded and present at app path.
7. `GA-13` completed: OAuth values extracted (`CLIENT_ID`, `REVERSED_CLIENT_ID`).
8. `GA-20` completed: Firebase + GoogleSignIn SPM wiring added.
9. `GA-21`, `GA-21A` completed: plist included in project and Resources.
10. `GA-22`, `GA-22A` completed: `FirebaseApp.configure()` added at startup.
11. `GA-30`, `GA-30A` completed: `AuthSessionManager` added for Google/Firebase auth + token handling.
12. `GA-31A` completed: bearer token provider integration confirmed.
13. `GA-40A` completed: welcome screen wired to Google sign-in flow.
14. `GA-41A` completed: restore-session behavior implemented.
15. `GA-60`/`GA-60B`/`GA-60C` completed: repeated integration builds succeeded.
16. `GA-61B`/`GA-61D`/`GA-61E` completed: simulator launch/install cycles succeeded.
17. `GA-62V` completed: built app plist validated for URL schemes and API keys.
18. `GA-62C` completed: runtime log inspection performed for sign-in exception checks.
19. `GA-51` pending: requires fresh live Firebase ID token for manual curl verification.

### Manual console/UI actions completed
- Enabled Google sign-in provider in Firebase Authentication (`GA-11`).
- Downloaded Firebase iOS config (`GoogleService-Info.plist`) for bundle `app.unstoppable.unstoppable` (`GA-12`).
- Confirmed and applied Google callback URL scheme using `REVERSED_CLIENT_ID` (`GA-13`).
- Interactive simulator sign-in tested with real Google account.

### Troubleshooting history (what failed and what fixed it)
1. Branch creation failure:
   - Symptom: `git checkout -b codex/google-auth-setup` failed with ref lock/directory creation error.
   - Action: continued safely on existing branch (`add-flow-docs`) for in-flight work; retried later.
   - Resolution: `GA-01D` branch creation succeeded.

2. CoreSimulator unavailable during baseline build:
   - Symptom: `CoreSimulatorService connection became invalid`, destination not found.
   - Action: validated simulator availability (`xcrun simctl list devices available`), then retried build.
   - Resolution: subsequent build `GA-02C` succeeded.

3. Shell logging helper compatibility issue:
   - Symptom: `run_step` used `PIPESTATUS` (bash-only), causing incorrect behavior in zsh sessions.
   - Action: updated helper to support both `${PIPESTATUS[0]}` (bash) and `${pipestatus[1]}` (zsh).
   - Resolution: reliable step exit-code logging in both shells (`GA-META`).

4. Simulator launch intermittently failed:
   - Symptom: first launch attempts (`GA-61`, `GA-61C`) exited non-zero.
   - Action: immediate reruns (`GA-61B`, `GA-61D`) plus rebuilds.
   - Resolution: app installed and launched successfully (PID recorded in log).

5. Google sign-in runtime crash on callback:
   - Symptom: `NSInvalidArgumentException` for missing URL scheme `com.googleusercontent.apps...`.
   - Action: added URL type settings via build settings, then validated runtime plist content.
   - Resolution: callback scheme present in built app; sign-in flow progressed.

6. Generated plist vs explicit plist mismatch:
   - Symptom: build settings-based URL scheme did not reliably produce expected runtime behavior.
   - Action: switched target to explicit plist (`GENERATE_INFOPLIST_FILE=NO`, `INFOPLIST_FILE=Unstoppable/Info.plist`) and placed API keys + URL types there.
   - Resolution: deterministic Info.plist output; build/launch/test passed.

7. Post-auth navigation regression (returned to Welcome):
   - Symptom: Google auth completed but app returned to `WelcomeView`.
   - Action: updated post-auth routing to drive forward based on onboarding state.
   - Resolution: routes to `HomeView` when onboarded; otherwise routes to `NicknameView`.

8. Back-navigation loop from NicknameView:
   - Symptom: tapping back returned immediately to `NicknameView` again.
   - Action: fixed restore routing to run once and cached bootstrap state.
   - Resolution: loop removed; compile and launch validated after fix.

### Key commands used during troubleshooting
```bash
xcrun simctl list devices available
xcodebuild -project "$XCODE_PROJECT_PATH" -scheme "$XCODE_SCHEME" -configuration Debug -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" build
/Users/luisgalvez/Projects/unstoppable/scripts/run_ios_sim.sh "$SIMULATOR_NAME"
/usr/libexec/PlistBuddy print CFBundleURLTypes /Users/luisgalvez/Projects/unstoppable/.build/Build/Products/Debug-iphonesimulator/Unstoppable.app/Info.plist
xcrun simctl spawn booted log show --last 2m --style compact --predicate 'process == "Unstoppable"'
```

### Current rollout state
- Google sign-in flow works end-to-end in simulator.
- Post-auth routing bug fixed.
- Nickname back-loop bug fixed.
- Remaining manual validation: run `GA-51` curl with a freshly captured Firebase ID token from an active signed-in session.

## Reusable Inputs (Set These First)
Replace values for each app rollout.

```bash
export APP_NAME="Unstoppable"
export IOS_BUNDLE_ID="app.unstoppable.unstoppable"
export XCODE_PROJECT_PATH="/Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj"
export XCODE_SCHEME="Unstoppable"
export SIMULATOR_NAME="iPhone 17 Pro"
export API_BASE_URL_DEV="https://unstoppable-api-1094359674860.us-central1.run.app"
export GCP_PROJECT_ID="unstoppable-app-dev"
export FIREBASE_PROJECT_ID="unstoppable-app-dev"
```

## Execution Logging Standard
Use this for every command during rollout.

### 1. Create execution log file
```bash
export EXEC_LOG="/Users/luisgalvez/Projects/unstoppable/GOOGLE_AUTH_EXECUTION_$(date +%Y%m%d_%H%M%S).log"
touch "$EXEC_LOG"
echo "Google Auth rollout log - $(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$EXEC_LOG"
```

### 2. Use step wrapper (recommended)
```bash
run_step() {
  local step="$1"
  shift
  echo "" | tee -a "$EXEC_LOG"
  echo "===== ${step} =====" | tee -a "$EXEC_LOG"
  echo "CMD: $*" | tee -a "$EXEC_LOG"
  "$@" 2>&1 | tee -a "$EXEC_LOG"
  local rc=0
  if [ -n "${BASH_VERSION:-}" ]; then
    rc=${PIPESTATUS[0]}
  elif [ -n "${ZSH_VERSION:-}" ]; then
    rc=${pipestatus[1]}
  fi
  echo "EXIT_CODE: ${rc}" | tee -a "$EXEC_LOG"
  return ${rc}
}
```

### 3. Log non-command actions
For console/UI actions (Firebase Console, Xcode GUI), add manual entries:

```bash
echo "ACTION: [GA-XX] Enabled Google provider in Firebase Console (who/when/result)" | tee -a "$EXEC_LOG"
```

## Step Plan (With IDs)

## Phase 0: Baseline and Branch

### GA-00: Confirm clean starting point
```bash
run_step GA-00 git -C /Users/luisgalvez/Projects/unstoppable status --short
run_step GA-00A git -C /Users/luisgalvez/Projects/unstoppable rev-parse --abbrev-ref HEAD
```
Acceptance:
- Current branch captured.
- Starting state recorded.

### GA-01: Create working branch
```bash
run_step GA-01 git -C /Users/luisgalvez/Projects/unstoppable checkout -b codex/google-auth-setup
```
Acceptance:
- New branch exists and is active.

### GA-02: Verify app builds before auth changes
```bash
run_step GA-02 xcodebuild -project "$XCODE_PROJECT_PATH" -scheme "$XCODE_SCHEME" -configuration Debug -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" build
```
Acceptance:
- Baseline build succeeds.

## Phase 1: Firebase + Google Provider Setup

### GA-10: Verify active cloud account/project
```bash
run_step GA-10 gcloud config get-value account
run_step GA-10A gcloud config get-value project
```
Acceptance:
- Active account and project logged.

### GA-11: Enable Firebase Authentication Google provider (console action)
Manual action:
- Open Firebase Console for `$FIREBASE_PROJECT_ID`.
- Authentication -> Sign-in method -> enable Google provider.

Logging entry:
```bash
echo "ACTION: [GA-11] Enabled Google provider in Firebase Auth for $FIREBASE_PROJECT_ID" | tee -a "$EXEC_LOG"
```
Acceptance:
- Google provider marked enabled in console.

### GA-12: Ensure iOS app registration + config file
Manual action:
- Firebase Console -> Project settings -> iOS app (`$IOS_BUNDLE_ID`).
- Download `GoogleService-Info.plist`.

Logging entry:
```bash
echo "ACTION: [GA-12] Downloaded GoogleService-Info.plist for bundle $IOS_BUNDLE_ID" | tee -a "$EXEC_LOG"
```
Acceptance:
- `GoogleService-Info.plist` available locally.

### GA-13: Confirm OAuth callback URL scheme values
Manual action:
- Read `REVERSED_CLIENT_ID` from `GoogleService-Info.plist`.
- Ensure this URL scheme is added to iOS app target.

Logging entry:
```bash
echo "ACTION: [GA-13] Verified REVERSED_CLIENT_ID URL scheme registration" | tee -a "$EXEC_LOG"
```
Acceptance:
- URL callback scheme configured.

## Phase 2: iOS Dependency + Project Wiring

### GA-20: Add SDK packages
Required packages:
- Firebase iOS SDK (at least `FirebaseAuth`)
- GoogleSignIn iOS SDK

Suggested package URLs:
- `https://github.com/firebase/firebase-ios-sdk`
- `https://github.com/google/GoogleSignIn-iOS`

Logging entry:
```bash
echo "ACTION: [GA-20] Added SPM packages: FirebaseAuth + GoogleSignIn" | tee -a "$EXEC_LOG"
```
Acceptance:
- Build target resolves package dependencies.

### GA-21: Add `GoogleService-Info.plist` to app target
Manual action:
- Drag into Xcode project and confirm target membership for app target.

Validation command:
```bash
run_step GA-21A rg -n "GoogleService-Info.plist" "$XCODE_PROJECT_PATH/project.pbxproj"
```
Acceptance:
- File referenced in project and target.

### GA-22: Initialize Firebase at app startup
Code action:
- Update `/Users/luisgalvez/Projects/unstoppable/Unstoppable/UnstoppableApp.swift`
- Import FirebaseCore and call `FirebaseApp.configure()`.

Validation command:
```bash
run_step GA-22A rg -n "FirebaseApp\\.configure|import FirebaseCore" /Users/luisgalvez/Projects/unstoppable/Unstoppable/UnstoppableApp.swift
```
Acceptance:
- Firebase initialized exactly once on launch.

## Phase 3: Auth Service Layer

### GA-30: Create dedicated auth service
Code action:
- Add a service (example: `AuthSessionManager`) responsible for:
  - Google sign-in flow.
  - Firebase credential exchange.
  - ID token retrieval/refresh.
  - Session restore/sign-out.

Expected files (example):
- `/Users/luisgalvez/Projects/unstoppable/Unstoppable/Auth/AuthSessionManager.swift`

Validation command:
```bash
run_step GA-30A rg -n "class AuthSessionManager|struct AuthSessionManager|signInWithGoogle|idToken" /Users/luisgalvez/Projects/unstoppable/Unstoppable
```
Acceptance:
- UI does not directly own low-level OAuth token exchange logic.

### GA-31: Expose async token provider for API layer
Code action:
- On sign-in success, set:
  - `UserDataSyncService.setAuthMode(.bearerTokenProvider { ... })`

Validation command:
```bash
run_step GA-31A rg -n "bearerTokenProvider|setAuthMode\\(" /Users/luisgalvez/Projects/unstoppable/Unstoppable
```
Acceptance:
- API uses bearer token auth after login.

## Phase 4: UI Wiring (`Continue with Google`)

### GA-40: Wire button action in welcome screen
Code action:
- Update `/Users/luisgalvez/Projects/unstoppable/Unstoppable/WelcomeView.swift`:
  - trigger auth service sign-in.
  - handle success/failure/cancel.
  - call bootstrap after auth mode switch.

Validation command:
```bash
run_step GA-40A rg -n "Continue with Google|signInWithGoogle|bootstrapIfNeeded" /Users/luisgalvez/Projects/unstoppable/Unstoppable/WelcomeView.swift
```
Acceptance:
- Button performs real auth flow.

### GA-41: Session restore on cold start
Code action:
- If Firebase `currentUser` exists, restore authenticated API mode on app launch.

Validation command:
```bash
run_step GA-41A rg -n "currentUser|restore|FirebaseAuth" /Users/luisgalvez/Projects/unstoppable/Unstoppable
```
Acceptance:
- Relaunch stays authenticated until explicit sign-out.

## Phase 5: Backend/Auth Policy Alignment

### GA-50: Keep dev header only for Debug rollout (temporary)
Current behavior exists in:
- `/Users/luisgalvez/Projects/unstoppable/backend/api/src/app.py`
- `/Users/luisgalvez/Projects/unstoppable/Unstoppable/Networking/APIClient.swift`

Validation commands:
```bash
run_step GA-50A rg -n "ALLOW_DEV_USER_HEADER|X-User-Id|API_USE_DEV_AUTH" /Users/luisgalvez/Projects/unstoppable
```
Acceptance:
- Release path uses bearer token auth.

### GA-51: Validate backend with real Firebase ID token
Command (replace token):
```bash
export FIREBASE_ID_TOKEN="<paste-id-token>"
run_step GA-51 curl -i -H "Authorization: Bearer $FIREBASE_ID_TOKEN" "$API_BASE_URL_DEV/v1/bootstrap"
```
Acceptance:
- Returns `200` with expected user payload.

## Phase 6: Validation and Regression Checks

### GA-60: Build after integration
```bash
run_step GA-60 xcodebuild -project "$XCODE_PROJECT_PATH" -scheme "$XCODE_SCHEME" -configuration Debug -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" build
```

### GA-61: Launch in simulator
```bash
run_step GA-61 /Users/luisgalvez/Projects/unstoppable/scripts/run_ios_sim.sh "$SIMULATOR_NAME"
```

### GA-62: Stream app logs while testing sign-in
```bash
run_step GA-62 xcrun simctl spawn booted log stream --level debug --predicate 'process == "Unstoppable"'
```

Functional checks:
- New user can sign in with Google.
- Existing user session restores on relaunch.
- API calls include `Authorization` header and avoid 401s.
- Sign-out forces unauthenticated state.

## Commit and Handoff

### GA-70: Commit with traceable message
```bash
run_step GA-70 git -C /Users/luisgalvez/Projects/unstoppable add .
run_step GA-70A git -C /Users/luisgalvez/Projects/unstoppable commit -m "Add Google sign-in with Firebase ID token API auth"
```

### GA-71: Record summary
Log:
- files changed,
- commands run,
- final test results,
- unresolved issues.

## Reuse Notes (For Other Apps)
- Keep this file and only replace the values under `Reusable Inputs`.
- Reuse the same step IDs (`GA-*`) to compare rollouts across repositories.
- Keep one execution log file per rollout (`GOOGLE_AUTH_EXECUTION_*.log`).
- If app/backend architecture differs, keep the logging format unchanged and only adjust implementation details.

## Quick Checklist
- [x] Google provider enabled in Firebase Auth.
- [x] `GoogleService-Info.plist` added to app target.
- [x] URL scheme for callback configured.
- [x] Firebase initialized in app startup.
- [x] Google sign-in flow implemented in auth service.
- [x] API switched to bearer token provider after login.
- [x] Session restore implemented.
- [x] Debug-only fallback auth reviewed.
- [x] End-to-end test passed in simulator.
- [x] Execution log saved and attached to change review.
