import Foundation

#if DEBUG && canImport(StoreKitTest)
import StoreKitTest

@MainActor
final class DebugStoreKitSessionManager {
    static let shared = DebugStoreKitSessionManager()

    private let apiKeyInfoKey = "REVENUECAT_IOS_API_KEY"
    private let debugAppleAPIKeyInfoKey = "REVENUECAT_DEBUG_APPLE_API_KEY"
    private let debugUseAppleAPIKeyInfoKey = "REVENUECAT_DEBUG_USE_APPLE_API_KEY"
    private let storeKitConfigName = "UnstoppableLocal"
    private var session: SKTestSession?

    private init() {}

    func configureIfNeeded() {
        guard session == nil else { return }
        guard usesRevenueCatTestKey else { return }

        do {
            let session = try SKTestSession(configurationFileNamed: storeKitConfigName)
            session.disableDialogs = true
            session.askToBuyEnabled = false
            self.session = session
        } catch {
            print("Debug StoreKit session setup failed: \(error.localizedDescription)")
        }
    }

    private var usesRevenueCatTestKey: Bool {
        if infoBool(forKey: debugUseAppleAPIKeyInfoKey),
           let appleKey = infoString(forKey: debugAppleAPIKeyInfoKey),
           appleKey.lowercased().hasPrefix("appl_") {
            return false
        }

        guard let apiKey = infoString(forKey: apiKeyInfoKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }

        return apiKey.hasPrefix("test_")
    }

    private func infoString(forKey key: String) -> String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }

    private func infoBool(forKey key: String) -> Bool {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: key)

        if let boolValue = rawValue as? Bool {
            return boolValue
        }

        guard let stringValue = (rawValue as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }

        switch stringValue {
        case "1", "true", "yes":
            return true
        default:
            return false
        }
    }
}
#else
@MainActor
final class DebugStoreKitSessionManager {
    static let shared = DebugStoreKitSessionManager()

    private init() {}

    func configureIfNeeded() {}
}
#endif
