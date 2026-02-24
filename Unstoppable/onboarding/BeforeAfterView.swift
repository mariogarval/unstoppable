import SwiftUI

struct BeforeAfterView: View {
    @State private var appeared = false
    @State private var showTerms = false
    @State private var termsAccepted = false

    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: 6, total: 7)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            Spacer()

            Text("This is the\ndifference.")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 36)

            // Before / After columns
            HStack(spacing: 14) {
                // BEFORE
                VStack(spacing: 0) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                        .frame(height: 40)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    Text("Before")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)

                    VStack(spacing: 10) {
                        BeforeItem("Hitting snooze again")
                        BeforeItem("Wasting the whole day")
                        BeforeItem("Wondering why nothing changes")
                    }
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -20)

                // AFTER
                VStack(spacing: 0) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.yellow)
                        .frame(height: 40)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    Text("After")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.orange)
                        .padding(.bottom, 16)

                    VStack(spacing: 10) {
                        AfterItem("Up before everyone")
                        AfterItem("Crushing it daily")
                        AfterItem("Discipline on autopilot")
                    }
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.yellow.opacity(0.12), .orange.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.yellow.opacity(0.4), lineWidth: 1)
                )
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : 20)
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                showTerms = true
            } label: {
                Text("Commit now")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityHint("Opens terms and conditions.")
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .opacity(appeared ? 1 : 0)
        }
        .background(.white)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                OnboardingBackButton(color: .primary)
            }
        }
        .sheet(isPresented: $showTerms) {
            TermsSheetView(didAccept: $termsAccepted)
        }
        .navigationDestination(isPresented: $termsAccepted) {
            PaywallView()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                appeared = true
            }
        }
    }
}

// MARK: - Row components

private struct BeforeItem: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color(.systemGray3))
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
}

private struct AfterItem: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(.orange)
                .clipShape(Circle())
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationStack {
        BeforeAfterView()
    }
}
