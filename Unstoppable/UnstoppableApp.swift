import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@main
struct UnstoppableApp: App {
    private enum LaunchRoute {
        case welcome, routineCreation, home
    }

    private var launchRoute: LaunchRoute {
        let hasCompletedOnboarding = StreakManager.userScopedBool(forKey: "hasCompletedOnboarding")
        let hasCreatedRoutine = StreakManager.userScopedBool(forKey: "hasCreatedRoutine")
        if !hasCompletedOnboarding {
            return .welcome
        }
        if !hasCreatedRoutine {
            return .routineCreation
        }
        return .home
    }

    private struct RootLaunchView: View {
        let route: LaunchRoute

        var body: some View {
            switch route {
            case .welcome:
                WelcomeView()
                    .task {
                        await AuthSessionManager.shared.restoreSessionIfPossible()
                    }
            case .routineCreation:
                NavigationStack {
                    RoutineCreationView()
                }
                .task {
                    await AuthSessionManager.shared.restoreSessionIfPossible()
                }
            case .home:
                NavigationStack {
                    HomeView()
                }
                .task {
                    await AuthSessionManager.shared.restoreSessionIfPossible()
                }
            }
        }
    }

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        UITestSupport.configureIfNeeded()
        RevenueCatManager.shared.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootLaunchView(route: launchRoute)
        }
    }
}

enum UITestSupport {
    private static let resetStateArgument = "UITEST_RESET_LOCAL_STATE"

    static var shouldBypassGuestBootstrap: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_SKIP_SIGNUP_DIRECT_TO_HOME")
    }

    static func configureIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains(resetStateArgument) else { return }

        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
        StreakManager.setAuthenticatedStorageScope(userID: nil)
        StreakManager.removeUserScopedValue(forKey: "hasCompletedOnboarding")
        StreakManager.removeUserScopedValue(forKey: "hasCreatedRoutine")
        UserDefaults.standard.removeObject(forKey: "stayOnWelcomeAfterSignOut")
        UserDefaults.standard.removeObject(forKey: "guest.sync.draft.state.v1")
        StreakManager.clearLocalTestingState()
    }
}
