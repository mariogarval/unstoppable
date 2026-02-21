import Foundation

enum PaymentRuntimeMode {
    case live
    case fakeActive
    case fakeInactive

    private static let fakeSubscriptionModeInfoKey = "REVENUECAT_FAKE_SUBSCRIPTION_MODE"

    static func current(bundle: Bundle = .main) -> PaymentRuntimeMode {
#if DEBUG
        guard let rawValue = (bundle.object(forInfoDictionaryKey: fakeSubscriptionModeInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return .live
        }

        switch rawValue {
        case "active":
            return .fakeActive
        case "inactive":
            return .fakeInactive
        default:
            return .live
        }
#else
        return .live
#endif
    }

    var isFake: Bool {
        switch self {
        case .live:
            return false
        case .fakeActive, .fakeInactive:
            return true
        }
    }

    var isPremiumActive: Bool {
        switch self {
        case .fakeActive:
            return true
        case .live, .fakeInactive:
            return false
        }
    }
}

enum PaymentManagerRouter {
    private static let runtimeMode = PaymentRuntimeMode.current()

    static var currentRuntimeMode: PaymentRuntimeMode {
        runtimeMode
    }

    @MainActor
    static func configureIfNeeded() {
        switch runtimeMode {
        case .live:
            RevenueCatManager.shared.configureIfNeeded()
        case .fakeActive, .fakeInactive:
            FakePaymentManager.shared.configureIfNeeded()
        }
    }

    @MainActor
    static func logIn(appUserID: String) async {
        switch runtimeMode {
        case .live:
            await RevenueCatManager.shared.logIn(appUserID: appUserID)
        case .fakeActive, .fakeInactive:
            await FakePaymentManager.shared.logIn(appUserID: appUserID)
        }
    }

    @MainActor
    static func logOut() async {
        switch runtimeMode {
        case .live:
            await RevenueCatManager.shared.logOut()
        case .fakeActive, .fakeInactive:
            await FakePaymentManager.shared.logOut()
        }
    }
}
