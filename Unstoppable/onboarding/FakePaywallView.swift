import SwiftUI

struct FakePaywallView: View {
    @State private var selectedPackageID: String?
    @State private var navigateHome = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var isSavingSelection = false
    @State private var purchaseErrorMessage: String?
    @StateObject private var revenueCat = FakePaymentManager.shared
    private let syncService = UserDataSyncService.shared

    private var selectedPackage: PaywallPackage? {
        guard let selectedPackageID else { return nil }
        return revenueCat.packages.first(where: { $0.id == selectedPackageID })
    }

    private var ctaTitle: String {
        if isPurchasing {
            return "Processing..."
        }
        if let selectedPackage {
            return "Continue (Fake) - \(selectedPackage.price)"
        }
        return "Select a plan"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Fake Payment Mode")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                Text("RevenueCat offerings are bypassed. This flow simulates purchase state and validates API writes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(revenueCat.packages) { package in
                        PlanCard(
                            title: package.title,
                            price: package.price,
                            detail: package.detail,
                            badge: package.isRecommended ? "TEST DEFAULT" : "TEST",
                            isSelected: selectedPackageID == package.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedPackageID = package.id
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                if revenueCat.packages.isEmpty {
                    Text("No fake plans loaded yet. Pull to refresh or reopen this screen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                if let purchaseErrorMessage {
                    Text(purchaseErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Button {
                    Task {
                        await purchaseSelectedPackage()
                    }
                } label: {
                    Text(ctaTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .padding(.horizontal, 20)
                .disabled(isPurchasing || isRestoring || isSavingSelection || selectedPackageID == nil)

                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    Text(isRestoring ? "Restoring..." : "Restore Purchases (Fake)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing || isRestoring || isSavingSelection)

                Button {
                    Task {
                        await completePaywallSelection("skip")
                    }
                } label: {
                    Text("Stay limited. Your call.")
                        .font(.callout)
                        .foregroundStyle(.tint)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing || isRestoring || isSavingSelection)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                DismissButton {
                    Task {
                        await completePaywallSelection("dismiss")
                    }
                }
            }
        }
        .task {
            await revenueCat.refreshPaywall()
            if selectedPackageID == nil {
                selectedPackageID = revenueCat.defaultPackageID()
            }
        }
        .onChange(of: revenueCat.packages) { _, newPackages in
            guard !newPackages.isEmpty else { return }
            if let selectedPackageID, newPackages.contains(where: { $0.id == selectedPackageID }) {
                return
            }
            self.selectedPackageID = revenueCat.defaultPackageID()
        }
        .navigationDestination(isPresented: $navigateHome) {
            HomeView()
        }
    }

    @MainActor
    private func purchaseSelectedPackage() async {
        guard let selectedPackage else {
            purchaseErrorMessage = "Select a plan first."
            return
        }
        await purchase(selectedPackage)
    }

    @MainActor
    private func purchase(_ package: PaywallPackage) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseErrorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await revenueCat.purchase(packageID: package.id)
            switch result {
            case .purchased:
                await completePaywallSelection(package.paymentOption)
            case .cancelled:
                break
            }
        } catch {
            purchaseErrorMessage = "Fake purchase failed. Please try again."
#if DEBUG
            print("Fake paywall purchase failed: \(error.localizedDescription)")
#endif
        }
    }

    @MainActor
    private func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        purchaseErrorMessage = nil
        defer { isRestoring = false }

        do {
            let restored = try await revenueCat.restorePurchases()
            if restored {
                await completePaywallSelection("restore")
            } else {
                purchaseErrorMessage = "No active fake subscription found to restore."
            }
        } catch {
            purchaseErrorMessage = "Fake restore failed. Please try again."
#if DEBUG
            print("Fake paywall restore failed: \(error.localizedDescription)")
#endif
        }
    }

    @MainActor
    private func completePaywallSelection(_ option: String) async {
        guard !isSavingSelection else { return }
        isSavingSelection = true
        purchaseErrorMessage = nil
        defer { isSavingSelection = false }

        do {
            _ = try await syncService.syncUserProfile(
                UserProfileUpsertRequest(paymentOption: option)
            )
            navigateHome = true
        } catch {
            purchaseErrorMessage = "Could not save your selection. Please try again."
#if DEBUG
            print("syncUserProfile(paymentOption) from fake paywall failed: \(error.localizedDescription)")
#endif
        }
    }
}
