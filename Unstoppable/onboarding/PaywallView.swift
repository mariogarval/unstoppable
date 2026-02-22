import SwiftUI

struct PaywallView: View {
    @State private var selectedPlan: Plan = .annual
    @State private var selectedPackageID: String?
    @State private var navigateHome = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var isSavingSelection = false
    @State private var purchaseErrorMessage: String?
    @StateObject private var revenueCat = RevenueCatManager.shared
    private let syncService = UserDataSyncService.shared

    enum Plan: String { case annual, monthly }

    private var selectedDynamicPackage: PaywallPackage? {
        guard let selectedPackageID else { return nil }
        return revenueCat.packages.first(where: { $0.id == selectedPackageID })
    }

    private var fallbackPackage: PaywallPackage? {
        if let selectedDynamicPackage {
            return selectedDynamicPackage
        }
        if let defaultID = revenueCat.defaultPackageID(),
           let package = revenueCat.packages.first(where: { $0.id == defaultID }) {
            return package
        }
        return revenueCat.packages.first
    }

    private var ctaTitle: String {
        if isPurchasing {
            return "Processing..."
        }

        if let selectedDynamicPackage {
            return "Continue - \(selectedDynamicPackage.price)"
        }

        if revenueCat.isLoadingOfferings {
            return "Loading plans..."
        }

        if revenueCat.packages.isEmpty {
            return "Retry loading plans"
        }

        return selectedPlan == .annual ? "Start Now. 7 Days Free." : "Subscribe. No Excuses."
    }

    private var ctaIconName: String {
        if let selectedDynamicPackage {
            return selectedDynamicPackage.isRecommended ? "sparkles" : "checkmark.seal.fill"
        }

        if revenueCat.packages.isEmpty {
            return "arrow.clockwise"
        }

        return selectedPlan == .annual ? "sparkles" : "checkmark.seal.fill"
    }

    private var trialEndDate: String {
        let date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return date.formatted(.dateTime.month(.wide).day().year())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Confetti decorations
                ConfettiHeader()

                // Headline
                Text("Most people quit\non day 3.")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 8)

                Text("Don\u{2019}t be most people. $2.29/month is less than one coffee.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                // Timeline
                VStack(spacing: 0) {
                    TimelineRow(
                        icon: "lock.open.fill",
                        iconColor: .orange,
                        day: "Today",
                        text: "Full access. No limits. Go.",
                        showLine: true
                    )
                    TimelineRow(
                        icon: "bell.fill",
                        iconColor: .blue,
                        day: "Day 5",
                        text: "We warn you before trial ends",
                        showLine: true
                    )
                    TimelineRow(
                        icon: "star.fill",
                        iconColor: .yellow,
                        day: "Day 7",
                        text: "Billing starts \(trialEndDate). Cancel anytime.",
                        showLine: false
                    )
                }
                .padding(20)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
                .padding(.top, 28)

                // Plan cards
                VStack(spacing: 12) {
                    if revenueCat.packages.isEmpty {
                        PlanCard(
                            title: "ANNUAL",
                            price: "Free",
                            detail: "1 week free, then US$27.49/yr",
                            badge: "BEST VALUE",
                            isSelected: selectedPlan == .annual
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedPlan = .annual
                                selectedPackageID = nil
                            }
                        }

                        PlanCard(
                            title: "MONTHLY",
                            price: "US$3.99",
                            detail: "charged monthly",
                            badge: nil,
                            isSelected: selectedPlan == .monthly
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedPlan = .monthly
                                selectedPackageID = nil
                            }
                        }
                    } else {
                        ForEach(revenueCat.packages) { package in
                            PlanCard(
                                title: package.title,
                                price: package.price,
                                detail: package.detail,
                                badge: package.isRecommended ? "BEST VALUE" : nil,
                                isSelected: selectedPackageID == package.id
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedPackageID = package.id
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                if revenueCat.packages.isEmpty {
                    Text(revenueCat.lastErrorMessage ?? "Subscriptions are temporarily unavailable. Tap retry while we refresh plans from App Store Connect.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Every feature. Zero restrictions.", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Label("Cancel anytime. We don\u{2019}t trap you.", systemImage: "xmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Text("Payment will be charged to your Apple ID account after the free trial ends. Subscription auto‑renews unless canceled at least 24 hours before the end of the period.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                if let purchaseErrorMessage {
                    Text(purchaseErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }

                // CTA
                Button {
                    Task {
                        await handleContinueTapped()
                    }
                } label: {
                    Label {
                        Text(ctaTitle)
                            .font(.headline)
                    } icon: {
                        Image(systemName: ctaIconName)
                    }
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                    .padding(.vertical, 2)
                    .tint(.orange)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .disabled(isPurchasing || isRestoring || revenueCat.isLoadingOfferings || isSavingSelection)
                .accessibilityHint("Starts a 7‑day free trial, then auto‑renews unless canceled.")

                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    Text(isRestoring ? "Restoring..." : "Restore Purchases")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing || isRestoring || revenueCat.isLoadingOfferings || isSavingSelection)

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
                .disabled(isPurchasing || isRestoring || revenueCat.isLoadingOfferings || isSavingSelection)
                .accessibilityHint("Continue without subscribing.")
                .padding(.bottom, 32)
            }
        }
        .scrollIndicators(.hidden)
        .background(
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)], startPoint: .top, endPoint: .bottom)
        )
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
    private func handleContinueTapped() async {
        if let package = fallbackPackage {
            selectedPackageID = package.id
            await purchase(package)
            return
        }

        purchaseErrorMessage = nil
        await revenueCat.refreshPaywall()

        if let package = fallbackPackage {
            selectedPackageID = package.id
            await purchase(package)
            return
        }

        purchaseErrorMessage = revenueCat.lastErrorMessage ?? "Subscription plans are still loading. Please retry in a moment."
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
            purchaseErrorMessage = "Purchase failed. Please try again."
#if DEBUG
            print("RevenueCat purchase failed: \(error.localizedDescription)")
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
                purchaseErrorMessage = "No active subscription found to restore."
            }
        } catch {
            purchaseErrorMessage = "Restore failed. Please try again."
#if DEBUG
            print("RevenueCat restore failed: \(error.localizedDescription)")
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
            print("syncUserProfile(paymentOption) failed: \(error.localizedDescription)")
#endif
        }
    }
}

// MARK: - Dismiss button

struct DismissButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.thinMaterial)
                .clipShape(Circle())
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Confetti header

private struct ConfettiHeader: View {
    var body: some View {
        ZStack {
            // Scattered confetti dots
            ConfettiDot(color: .orange.opacity(0.5), size: 8, x: -120, y: 10)
            ConfettiDot(color: .yellow.opacity(0.6), size: 12, x: -80, y: -10)
            ConfettiDot(color: .blue.opacity(0.3), size: 6, x: -40, y: 20)
            ConfettiDot(color: .pink.opacity(0.4), size: 10, x: 30, y: -5)
            ConfettiDot(color: .green.opacity(0.3), size: 7, x: 70, y: 15)
            ConfettiDot(color: .purple.opacity(0.3), size: 9, x: 110, y: -8)
            ConfettiDot(color: .yellow.opacity(0.5), size: 11, x: -60, y: 35)
            ConfettiDot(color: .orange.opacity(0.4), size: 6, x: 90, y: 30)

            // Star accents
            Image(systemName: "sparkle")
                .font(.title3)
                .foregroundStyle(.yellow)
                .offset(x: -100, y: -15)
            Image(systemName: "sparkle")
                .font(.caption)
                .foregroundStyle(.orange.opacity(0.6))
                .offset(x: 105, y: 5)

            // Crown
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
        }
        .frame(height: 88)
        .padding(.top, 20)
    }
}

private struct ConfettiDot: View {
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: x, y: y)
    }
}

// MARK: - Timeline row

private struct TimelineRow: View {
    let icon: String
    let iconColor: Color
    let day: String
    let text: String
    let showLine: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                    .background(.thinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(iconColor.opacity(0.35), lineWidth: 1))

                if showLine {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2, height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(day)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Spacer()
        }
    }
}

// MARK: - Plan card

struct PlanCard: View {
    let title: String
    let price: String
    let detail: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Radio
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.tint)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 4) {
                        Text(price)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("— \(detail)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.yellow.opacity(0.08))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : Color(.separator), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    NavigationStack {
        PaywallView()
    }
}
