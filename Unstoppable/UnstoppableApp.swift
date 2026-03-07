import SwiftUI
import FirebaseCore

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
        RevenueCatManager.shared.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootLaunchView(route: launchRoute)
        }
    }
}
