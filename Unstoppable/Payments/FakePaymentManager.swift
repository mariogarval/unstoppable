import Foundation

private struct FakeSubscriptionPlan {
    let packageID: String
    let productID: String
    let title: String
    let price: String
    let detail: String
    let paymentOption: String
    let isRecommended: Bool
}

enum FakePaymentManagerError: LocalizedError {
    case modeDisabled
    case packageUnavailable

    var errorDescription: String? {
        switch self {
        case .modeDisabled:
            return "Fake payment mode is disabled."
        case .packageUnavailable:
            return "Selected package is unavailable."
        }
    }
}

@MainActor
final class FakePaymentManager: ObservableObject {
    static let shared = FakePaymentManager()

    @Published private(set) var packages: [PaywallPackage] = []
    @Published private(set) var isLoadingOfferings = false
    @Published private(set) var isPremiumActive = false
    @Published private(set) var isConfigured = false
    @Published private(set) var lastErrorMessage: String?

    private let entitlementID = "premium"
    private let fakeSubscriptionStore = "debug_fake"
    private let fakeSubscriptionPeriodType = "normal"
    private let runtimeMode = PaymentRuntimeMode.current()
    private let fakePlans: [FakeSubscriptionPlan] = [
        FakeSubscriptionPlan(
            packageID: "debug.unstoppable.package.annual",
            productID: "debug.unstoppable.premium.annual",
            title: "ANNUAL",
            price: "US$27.49",
            detail: "billed yearly",
            paymentOption: "annual",
            isRecommended: true
        ),
        FakeSubscriptionPlan(
            packageID: "debug.unstoppable.package.monthly",
            productID: "debug.unstoppable.premium.monthly",
            title: "MONTHLY",
            price: "US$3.99",
            detail: "billed monthly",
            paymentOption: "monthly",
            isRecommended: false
        ),
    ]

    private var fakePlanByPackageID: [String: FakeSubscriptionPlan] = [:]
    private var lastSelectedFakePackageID: String?

    func configureIfNeeded() {
        guard runtimeMode.isFake else {
            isConfigured = false
            packages = []
            lastErrorMessage = FakePaymentManagerError.modeDisabled.localizedDescription
            return
        }

        isConfigured = true
        lastErrorMessage = nil
    }

    func refreshPaywall() async {
        guard runtimeMode.isFake else {
            lastErrorMessage = FakePaymentManagerError.modeDisabled.localizedDescription
            return
        }

        if !isConfigured {
            configureIfNeeded()
        }

        loadFakeOfferings()
        isPremiumActive = runtimeMode.isPremiumActive
        await syncFakeSubscriptionSnapshot(selectedPackageID: lastSelectedFakePackageID)
    }

    func defaultPackageID() -> String? {
        if let annual = packages.first(where: { $0.paymentOption == "annual" }) {
            return annual.id
        }
        return packages.first?.id
    }

    func purchase(packageID: String) async throws -> RevenueCatPurchaseResult {
        guard runtimeMode.isFake else {
            throw FakePaymentManagerError.modeDisabled
        }

        guard packages.contains(where: { $0.id == packageID }) else {
            throw FakePaymentManagerError.packageUnavailable
        }

        lastSelectedFakePackageID = packageID
        isPremiumActive = runtimeMode.isPremiumActive
        await syncFakeSubscriptionSnapshot(selectedPackageID: packageID)
        return .purchased
    }

    func restorePurchases() async throws -> Bool {
        guard runtimeMode.isFake else {
            throw FakePaymentManagerError.modeDisabled
        }

        isPremiumActive = runtimeMode.isPremiumActive
        await syncFakeSubscriptionSnapshot(selectedPackageID: lastSelectedFakePackageID)
        return isPremiumActive
    }

    func logIn(appUserID: String) async {
        let trimmedID = appUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, runtimeMode.isFake else { return }

        if !isConfigured {
            configureIfNeeded()
        }

        isPremiumActive = runtimeMode.isPremiumActive
        await syncFakeSubscriptionSnapshot(selectedPackageID: lastSelectedFakePackageID)
    }

    func logOut() async {
        guard runtimeMode.isFake else { return }

        if !isConfigured {
            configureIfNeeded()
        }

        isPremiumActive = runtimeMode.isPremiumActive
        await syncFakeSubscriptionSnapshot(selectedPackageID: lastSelectedFakePackageID)
    }

    private func loadFakeOfferings() {
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }

        fakePlanByPackageID = Dictionary(uniqueKeysWithValues: fakePlans.map { ($0.packageID, $0) })
        packages = fakePlans.map {
            PaywallPackage(
                id: $0.packageID,
                title: $0.title,
                price: $0.price,
                detail: $0.detail,
                paymentOption: $0.paymentOption,
                isRecommended: $0.isRecommended
            )
        }

        if let selectedID = lastSelectedFakePackageID,
           !packages.contains(where: { $0.id == selectedID }) {
            lastSelectedFakePackageID = nil
        }

        if lastSelectedFakePackageID == nil {
            lastSelectedFakePackageID = defaultPackageID()
        }

        lastErrorMessage = nil
        isConfigured = true
    }

    private func fakePlan(for packageID: String?) -> FakeSubscriptionPlan? {
        guard let packageID else { return nil }

        if let mapped = fakePlanByPackageID[packageID] {
            return mapped
        }

        return fakePlans.first(where: { $0.packageID == packageID })
    }

    private func syncFakeSubscriptionSnapshot(selectedPackageID: String?) async {
        guard runtimeMode.isFake else { return }

        let selectedPlan =
            fakePlan(for: selectedPackageID)
            ?? fakePlan(for: lastSelectedFakePackageID)
            ?? fakePlans.first(where: { $0.paymentOption == "annual" })
            ?? fakePlans.first

        if let selectedPlan {
            lastSelectedFakePackageID = selectedPlan.packageID
        }

        let entitlementIDs = runtimeMode.isPremiumActive ? [entitlementID] : []
        let request = SubscriptionSnapshotUpsertRequest(
            entitlementId: runtimeMode.isPremiumActive ? entitlementID : nil,
            entitlementIds: entitlementIDs,
            isActive: runtimeMode.isPremiumActive,
            productId: selectedPlan?.productID,
            paymentOption: selectedPlan?.paymentOption,
            store: fakeSubscriptionStore,
            periodType: fakeSubscriptionPeriodType,
            expirationAt: nil,
            gracePeriodExpiresAt: nil
        )

        do {
            let _: APIAckResponse = try await APIClient.shared.post(
                "/v1/payments/subscription/snapshot",
                body: request,
                as: APIAckResponse.self
            )
        } catch {
#if DEBUG
            print("Fake subscription snapshot sync failed: \(error.localizedDescription)")
#endif
        }
    }
}
