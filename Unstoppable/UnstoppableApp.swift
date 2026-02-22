import SwiftUI
import FirebaseCore

@main
struct UnstoppableApp: App {
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        RevenueCatManager.shared.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
    }
}
