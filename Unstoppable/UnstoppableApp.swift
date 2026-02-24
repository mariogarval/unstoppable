import SwiftUI
import FirebaseCore

@main
struct UnstoppableApp: App {
    private enum LaunchRoute {
        case welcome, routineCreation, home
    }

    private static let launchRoute: LaunchRoute = {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasCreatedRoutine = UserDefaults.standard.bool(forKey: "hasCreatedRoutine")
        if !hasCompletedOnboarding {
            return .welcome
        }
        if !hasCreatedRoutine {
            return .routineCreation
        }
        return .home
    }()

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
            RootLaunchView(route: Self.launchRoute)
        }
    }
}
