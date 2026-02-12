import SwiftUI

struct PaywallView: View {
    @State private var selectedPlan: Plan = .annual
    @State private var navigateHome = false

    enum Plan { case annual, monthly }

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
                    PlanCard(
                        title: "ANNUAL",
                        price: "Free",
                        detail: "1 week free, then US$27.49/yr",
                        badge: "BEST VALUE",
                        isSelected: selectedPlan == .annual
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedPlan = .annual
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
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

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

                // CTA
                Button {
                    navigateHome = true
                } label: {
                    Label {
                        Text(selectedPlan == .annual ? "Start Now. 7 Days Free." : "Subscribe. No Excuses.")
                            .font(.headline)
                    } icon: {
                        Image(systemName: selectedPlan == .annual ? "sparkles" : "checkmark.seal.fill")
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
                .accessibilityHint("Starts a 7‑day free trial, then auto‑renews unless canceled.")

                Button {
                    navigateHome = true
                } label: {
                    Text("Stay limited. Your call.")
                        .font(.callout)
                        .foregroundStyle(.tint)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
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
                DismissButton(navigateHome: $navigateHome)
            }
        }
        .navigationDestination(isPresented: $navigateHome) {
            HomeView()
        }
    }
}

// MARK: - Dismiss button

private struct DismissButton: View {
    @Binding var navigateHome: Bool

    var body: some View {
        Button { navigateHome = true } label: {
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

private struct PlanCard: View {
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
