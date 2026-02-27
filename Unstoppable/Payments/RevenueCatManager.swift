import Foundation
import RevenueCat

struct PaywallPackage: Identifiable, Equatable {
    let id: String
    let title: String
    let price: String
    let detail: String
    let paymentOption: String
    let isRecommended: Bool
}

enum RevenueCatPurchaseResult {
    case purchased
    case cancelled
}

enum RevenueCatManagerError: LocalizedError {
    case missingAPIKey
    case packageUnavailable

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "RevenueCat API key is missing."
        case .packageUnavailable:
            return "Selected package is unavailable."
        }
    }
}

@MainActor
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()

    @Published private(set) var packages: [PaywallPackage] = []
    @Published private(set) var isLoadingOfferings = false
    @Published private(set) var isPremiumActive = false
    @Published private(set) var isConfigured = false
    @Published private(set) var lastErrorMessage: String?

    private let entitlementID = "premium"
    private let apiKeyInfoKey = "REVENUECAT_IOS_API_KEY"
    private let backendSyncEnabledInfoKey = "REVENUECAT_ENABLE_BACKEND_SYNC"
    private let syncService = UserDataSyncService.shared

    private var packageByID: [String: Package] = [:]
    private lazy var isBackendSyncEnabled = configuredBackendSyncEnabled()

    func configureIfNeeded() {
        if Purchases.isConfigured {
            Purchases.shared.delegate = self
            isConfigured = true
            return
        }

        guard let apiKey = configuredAPIKey() else {
            lastErrorMessage = RevenueCatManagerError.missingAPIKey.localizedDescription
            isConfigured = false
            return
        }

#if DEBUG
        Purchases.logLevel = .debug
#else
        Purchases.logLevel = .warn
#endif

        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        isConfigured = true
        lastErrorMessage = nil
    }

    func refreshPaywall() async {
        guard ensureConfigured() else { return }
        await loadOfferings()
        await refreshCustomerInfo()
    }

    func defaultPackageID() -> String? {
        if let annual = packages.first(where: { $0.paymentOption == "annual" }) {
            return annual.id
        }
        return packages.first?.id
    }

    func purchase(packageID: String) async throws -> RevenueCatPurchaseResult {
        guard ensureConfigured() else { throw RevenueCatManagerError.missingAPIKey }
        guard let package = packageByID[packageID] else { throw RevenueCatManagerError.packageUnavailable }

        let result = try await Purchases.shared.purchase(package: package)
        apply(customerInfo: result.customerInfo)
        return result.userCancelled ? .cancelled : .purchased
    }

    func restorePurchases() async throws -> Bool {
        guard ensureConfigured() else { throw RevenueCatManagerError.missingAPIKey }
        let customerInfo = try await Purchases.shared.restorePurchases()
        apply(customerInfo: customerInfo)
        return hasActiveEntitlement(customerInfo)
    }

    func logIn(appUserID: String, email: String? = nil) async {
        let trimmedID = appUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return }

        guard ensureConfigured() else { return }
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(trimmedID)
            syncEmailAttribute(email)
            apply(customerInfo: customerInfo)
        } catch {
#if DEBUG
            print("RevenueCat logIn failed: \(error.localizedDescription)")
#endif
        }
    }

    func logOut() async {
        guard ensureConfigured() else { return }

        do {
            let customerInfo = try await Purchases.shared.logOut()
            apply(customerInfo: customerInfo)
        } catch {
#if DEBUG
            print("RevenueCat logOut failed: \(error.localizedDescription)")
#endif
        }
    }

    func paymentOption(forPackageID packageID: String) -> String? {
        packages.first(where: { $0.id == packageID })?.paymentOption
    }

    private func loadOfferings() async {
        guard ensureConfigured() else { return }

        isLoadingOfferings = true
        defer { isLoadingOfferings = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let currentOffering = offerings.current else {
                packages = []
                packageByID = [:]
                lastErrorMessage = "No current RevenueCat offering is configured. Set one as Current in the RevenueCat dashboard."
#if DEBUG
                print("RevenueCat offerings loaded but current offering is nil. Offerings: \(offerings.all.keys.sorted())")
#endif
                return
            }

            let availablePackages = currentOffering.availablePackages
            if availablePackages.isEmpty {
                packages = []
                packageByID = [:]
                lastErrorMessage = "RevenueCat offering has no packages. Attach monthly/yearly products to the Current offering."
#if DEBUG
                print("RevenueCat current offering has no packages. Offering id: \(currentOffering.identifier)")
#endif
                return
            }

            packageByID = Dictionary(uniqueKeysWithValues: availablePackages.map { ($0.identifier, $0) })
            packages = availablePackages.map(makePaywallPackage(from:))
            lastErrorMessage = nil
        } catch {
            packages = []
            packageByID = [:]
            lastErrorMessage = "Unable to load plans right now."
#if DEBUG
            print("RevenueCat offerings load failed: \(error.localizedDescription)")
#endif
        }
    }

    private func refreshCustomerInfo() async {
        guard ensureConfigured() else { return }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            apply(customerInfo: customerInfo)
        } catch {
#if DEBUG
            print("RevenueCat customer info refresh failed: \(error.localizedDescription)")
#endif
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        isPremiumActive = hasActiveEntitlement(customerInfo)
        if isBackendSyncEnabled {
            Task {
                await syncSubscriptionSnapshot(customerInfo: customerInfo)
            }
        }
    }

    private func hasActiveEntitlement(_ customerInfo: CustomerInfo) -> Bool {
        customerInfo.entitlements.active[entitlementID] != nil
    }

    private func ensureConfigured() -> Bool {
        if !isConfigured {
            configureIfNeeded()
        }
        return isConfigured
    }

    private func syncEmailAttribute(_ rawEmail: String?) {
        let normalized = rawEmail?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let normalized, !normalized.isEmpty else {
            return
        }
        Purchases.shared.attribution.setEmail(normalized)
    }

    private func configuredAPIKey() -> String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: apiKeyInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }

    private func configuredBackendSyncEnabled() -> Bool {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: backendSyncEnabledInfoKey)

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

    private func makePaywallPackage(from package: Package) -> PaywallPackage {
        let paymentOption = paymentOption(for: package)
        let title = title(for: package)
        let detail = detail(for: package)

        return PaywallPackage(
            id: package.identifier,
            title: title,
            price: package.storeProduct.localizedPriceString,
            detail: detail,
            paymentOption: paymentOption,
            isRecommended: package.packageType == .annual
        )
    }

    private func paymentOption(for package: Package) -> String {
        if let fromProductID = paymentOption(forIdentifier: package.storeProduct.productIdentifier) {
            return fromProductID
        }
        if let fromPackageID = paymentOption(forIdentifier: package.identifier) {
            return fromPackageID
        }
        return paymentOption(for: package.packageType)
    }

    private func paymentOption(for packageType: PackageType) -> String {
        switch packageType {
        case .annual:
            return "annual"
        case .monthly:
            return "monthly"
        case .weekly:
            return "weekly"
        case .lifetime:
            return "lifetime"
        default:
            return "custom"
        }
    }

    private func title(for package: Package) -> String {
        switch package.packageType {
        case .annual:
            return "ANNUAL"
        case .monthly:
            return "MONTHLY"
        case .weekly:
            return "WEEKLY"
        case .lifetime:
            return "LIFETIME"
        default:
            let fallback = package.storeProduct.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? "PLAN" : fallback.uppercased()
        }
    }

    private func detail(for package: Package) -> String {
        let trimmed = package.storeProduct.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        switch package.packageType {
        case .annual:
            return "billed yearly"
        case .monthly:
            return "billed monthly"
        case .weekly:
            return "billed weekly"
        case .lifetime:
            return "one-time purchase"
        default:
            return "subscription"
        }
    }

    private func syncSubscriptionSnapshot(customerInfo: CustomerInfo) async {
        let activeEntitlement = customerInfo.entitlements.active[entitlementID]
        let entitlementIDs = Array(customerInfo.entitlements.active.keys).sorted()
        let productID = activeEntitlement?.productIdentifier ?? customerInfo.activeSubscriptions.first
        let inferredPaymentOption = paymentOption(forProductID: productID)
        let request = SubscriptionSnapshotUpsertRequest(
            entitlementId: activeEntitlement == nil ? nil : entitlementID,
            entitlementIds: entitlementIDs,
            isActive: hasActiveEntitlement(customerInfo),
            productId: productID,
            paymentOption: inferredPaymentOption,
            store: nil,
            periodType: activeEntitlement.map { "\($0.periodType)" },
            expirationAt: activeEntitlement?.expirationDate,
            gracePeriodExpiresAt: nil
        )

        do {
            _ = try await syncService.syncSubscriptionSnapshot(request)
        } catch {
#if DEBUG
            print("RevenueCat subscription snapshot sync failed: \(error.localizedDescription)")
#endif
        }
    }

    private func paymentOption(forProductID productID: String?) -> String? {
        guard let rawProductID = productID?.trimmingCharacters(in: .whitespacesAndNewlines), !rawProductID.isEmpty else {
            return nil
        }

        if let package = packageByID.values.first(where: { $0.storeProduct.productIdentifier == rawProductID }) {
            return paymentOption(for: package)
        }

        return paymentOption(forIdentifier: rawProductID)
    }

    private func paymentOption(forIdentifier identifier: String?) -> String? {
        guard let identifier = identifier?.trimmingCharacters(in: .whitespacesAndNewlines), !identifier.isEmpty else {
            return nil
        }

        let normalized = identifier.lowercased()
        if normalized.contains("annual") || normalized.contains("yearly") || normalized.contains("year") {
            return "annual"
        }
        if normalized.contains("monthly") || normalized.contains("month") {
            return "monthly"
        }
        if normalized.contains("weekly") || normalized.contains("week") {
            return "weekly"
        }
        if normalized.contains("lifetime") || normalized.contains("life") {
            return "lifetime"
        }
        return nil
    }
}

extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo: customerInfo)
        }
    }
}
