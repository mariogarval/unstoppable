import SwiftUI

struct GenderSelectionView: View {
    @State private var navigateNext = false
    private let syncService = UserDataSyncService.shared

    private let genders: [(label: String, icon: String)] = [
        ("Female", "figure.stand.dress"),
        ("Male", "figure.stand"),
        ("Neither", "circle.hexagongrid"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: 6, total: 6)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("What is your gender?")
                    .font(.title.bold())
                Text("I recommend routines for your gender.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 28)

            VStack(spacing: 10) {
                ForEach(genders, id: \.label) { gender in
                    Button {
                        syncGender(gender.label)
                        navigateNext = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: gender.icon)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(gender.label)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 20)
                        .frame(minHeight: 52)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityHint("Selects this option.")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()

            Button {
                navigateNext = true
            } label: {
                Text("Do not select")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
            .accessibilityHint("Continues without choosing a gender.")
            .padding(.bottom, 24)
        }
        .background(.white)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                OnboardingBackButton(color: .primary)
            }
        }
        .navigationDestination(isPresented: $navigateNext) {
            NotificationPermissionView()
        }
    }

    private func syncGender(_ gender: String) {
        Task {
            do {
                _ = try await syncService.syncUserProfile(
                    UserProfileUpsertRequest(
                        nickname: nil,
                        ageGroup: nil,
                        gender: gender,
                        notificationsEnabled: nil,
                        termsAccepted: nil
                    )
                )
            } catch {
#if DEBUG
                print("syncUserProfile(gender) failed: \(error.localizedDescription)")
#endif
            }
        }
    }
}

#Preview {
    NavigationStack {
        GenderSelectionView()
    }
}
