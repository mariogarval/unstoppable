import SwiftUI

struct GenderSelectionView: View {
    @State private var navigateNext = false
    @State private var isSavingProfile = false
    @State private var syncErrorMessage: String?
    private let syncService = UserDataSyncService.shared

    private let genders: [(label: String, icon: String)] = [
        ("Female", "figure.stand.dress"),
        ("Male", "figure.stand"),
        ("Neither", "circle.hexagongrid"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: 3, total: 7)
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
                        Task {
                            await continueWithGender(gender.label)
                        }
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
                    .disabled(isSavingProfile)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            if let syncErrorMessage {
                Text(syncErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

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
            .disabled(isSavingProfile)
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
            GoalSelectionView()
        }
    }

    @MainActor
    private func continueWithGender(_ gender: String) async {
        isSavingProfile = true
        syncErrorMessage = nil
        defer { isSavingProfile = false }

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
            print("syncUserProfile(gender) failed (non-blocking): \(error.localizedDescription)")
#endif
        }
        navigateNext = true
    }
}

#Preview {
    NavigationStack {
        GenderSelectionView()
    }
}
