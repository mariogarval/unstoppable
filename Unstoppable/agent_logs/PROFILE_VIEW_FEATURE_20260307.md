# Profile View Feature

**Date**: 2026-03-07
**Status**: Complete
**Branch**: `agentic-dev-v1`

## Summary

Added a Profile View accessible from Settings that displays user profile information. Moved reset profile functionality from Settings into the Profile View (debug-only), with separate reset options depending on auth state.

## Problem Solved

Users had no way to view their saved profile data (nickname, age group, gender, goals, terms, etc.) within the app. The reset profile debug button was placed in Settings without contextual relevance.

## Changes

### New File
- **`Unstoppable/ProfileView.swift`** - New SwiftUI view showing profile data loaded from bootstrap (works for both guest and logged-in users).

### Modified Files
- **`Unstoppable/HomeView.swift`** - Added "View Profile" NavigationLink in SettingsTab. Removed reset local profile button, its state, alert, and function from Settings.
- **`Unstoppable/Networking/APIClient.swift`** - Added `HTTPMethod.delete` case and `delete()` method.
- **`Unstoppable/Sync/UserDataSyncService.swift`** - Added `resetAPIProfile()` method calling `DELETE /v1/user/profile`.
- **`Unstoppable.xcodeproj/project.pbxproj`** - Registered `ProfileView.swift` in build file, file reference, group, and sources build phase.
- **`backend/api/src/app.py`** - Added `DELETE /v1/user/profile` endpoint that deletes the user's `users/{uid}/profile/self` Firestore document.

## Profile View Sections

| Section | Content |
|---------|---------|
| Account | User ID, auth status (Guest/Signed In), email (if logged in) |
| Personal | Nickname, Age Group, Gender |
| Goals | Ideal daily life selections |
| Preferences | Notifications status, Payment option |
| Terms | Terms accepted, Over 16 confirmed, Marketing accepted |
| Testing (debug-only) | Reset Local Profile (guest only), Reset API Profile (logged-in only) |

## Debug Reset Behavior

- **Guest users**: "Reset Local Profile" button clears local UserDefaults onboarding/profile data.
- **Logged-in users**: "Reset API Profile" button calls `DELETE /v1/user/profile` to delete server-side profile, then reloads the view.
- Both buttons gated by `SHOW_SETTINGS_RESET_LOCAL_PROFILE_TEST_BUTTON` Info.plist flag.

## Backend Deployment

- Deployed revision `unstoppable-api-00016-t5r` to Cloud Run with the new DELETE endpoint.
- Command: `ALLOW_UNAUTHENTICATED=1 backend/api/deploy_cloud_run.sh unstoppable-app-dev`

## Verification

- `xcodebuild` build succeeded.
- App installed and launched in iPhone 17 Pro simulator via `./scripts/run_ios_sim.sh`.
- Backend deployed and serving 100% traffic.

## Next Steps

- Profile data is read-only; editing individual fields from the profile view could be a future enhancement.
- API profile reset deletes the entire profile document; a more granular field-level reset could be added if needed.

## Related

- `HOME_ROUTINE_STATE_ISOLATION_20260307.md` (user scoping context)
- `PROFILE_COMPLETION_ROUTING_20260221.md` (bootstrap profile data pattern)
