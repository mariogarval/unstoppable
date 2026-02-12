# Unstoppable iOS App Flow + Backend Integration Guide

This project is a SwiftUI iOS app with a local-first flow.

## 1) Current App Entry and Navigation

### Real entry point
- `Unstoppable/UnstoppableApp.swift` launches `WelcomeView()`.

### Main path currently wired in the app
1. `WelcomeView` (`Unstoppable/WelcomeView.swift`)
2. `NicknameView` (`Unstoppable/NicknameView.swift`)
3. `AgeGroupView` (`Unstoppable/onboarding/AgeGroupView.swift`)
4. `GenderSelectionView` (`Unstoppable/onboarding/GenderSelectionView.swift`)
5. `NotificationPermissionView` (`Unstoppable/onboarding/NotificationPermissionView.swift`)
6. `BeforeAfterView` (`Unstoppable/onboarding/BeforeAfterView.swift`)
7. `TermsSheetView` modal (`Unstoppable/onboarding/TermsSheetView.swift`)
8. `PaywallView` (`Unstoppable/onboarding/PaywallView.swift`)
9. `HomeView` (`Unstoppable/HomeView.swift`)

### Inside `HomeView`
- `TabView` with:
  - Home tab: routine tasks and timer
  - Stats tab: streak analytics
  - Settings tab: theme/time/notifications/haptics

### Important note
There is a second onboarding chain (`RoutinePreviewView -> TimerDemoView -> SocialProofView -> GoalSelectionView`) that exists in code but is **not** connected from the current app entry flow.

## 2) Where User Data Lives Today

Data is currently local only.

### Streak + completion history
- `Unstoppable/StreakManager.swift`
- `StreakManager` is a singleton (`StreakManager.shared`).
- Stores:
  - `dailyRecords` (`[dateString: DayRecord]`)
  - `currentStreak`, `longestStreak`, `lastQualifiedDate`
- Persists to `UserDefaults` in `save()` / `load()`.

### In-memory UI state (not persisted to backend)
- `HomeView.swift`
  - `tasks` in `HomeTab`
  - `routineTime`, tab selection, sheet flags
- `AppSettings` object in `HomeView.swift` (theme, routine time, notification toggle, haptics)
- Onboarding choices are mostly used for navigation today and are not centrally persisted.

## 3) Where to Start Adding Backend Endpoints

If your goal is "save user data for this flow", start with the mutation points below.

### A) Save profile/onboarding completion first
- Trigger from:
  - `NicknameView` when user taps Next
  - `AgeGroupView` and `GenderSelectionView` when selection is made
  - `NotificationPermissionView` after permission result
  - `TermsSheetView` when accepted
- Why first: this gives you a server-side user profile before task/streak events.

### B) Save routine/task state
- Trigger from `HomeView.swift`:
  - `applyTemplate(_:)`
  - Add task action in `AddTaskSheet`
  - Task delete action in `TaskRow` context menu
  - Routine time change (`EditTimeSheet` -> `settings.routineTime`)

### C) Save progress + streak updates
- Trigger from `StreakManager.swift`:
  - `completeTask(taskID:totalTasks:)`
  - `uncompleteTask(taskID:totalTasks:)`
  - `recordBatchCompletion(completedIDs:totalTasks:)`
  - `checkAppLaunch()` (useful for streak resets)
- Best hook: call a sync API from inside `updateToday(totalTasks:)` after local state changes.

## 4) Recommended Backend API Shape (Minimal)

Use a minimal set first:

- `POST /v1/user/profile`
  - nickname, ageGroup, gender, notificationsEnabled, termsAccepted
- `PUT /v1/routines/current`
  - routineTime, task list (id/title/icon/duration/isCompleted)
- `POST /v1/progress/daily`
  - date, completed, total, completedTaskIds
- `GET /v1/bootstrap`
  - returns profile + current routine + streak snapshot for app launch restore
