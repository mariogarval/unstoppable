import SwiftUI

struct AgeGroupView: View {
    @State private var navigateNext = false
    @State private var isSavingProfile = false
    @State private var syncErrorMessage: String?
    private let syncService = UserDataSyncService.shared

    private let ageRanges = [
        "Under 15",
        "15–19",
        "20–24",
        "25–29",
        "30–34",
        "35–39",
        "40–44",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: 2, total: 7)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("What is your age group?")
                    .font(.title.bold())
                Text("I recommend routines for your age.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 28)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(ageRanges, id: \.self) { range in
                        Button {
                            Task {
                                await continueWithAgeGroup(range)
                            }
                        } label: {
                            HStack {
                                Text(range)
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
                        }
                        .accessibilityHint("Selects this age range.")
                        .disabled(isSavingProfile)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }

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
            .accessibilityHint("Continues without choosing an age group.")
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
            GenderSelectionView()
        }
    }

    @MainActor
    private func continueWithAgeGroup(_ ageGroup: String) async {
        isSavingProfile = true
        syncErrorMessage = nil
        defer { isSavingProfile = false }

        do {
            _ = try await syncService.syncUserProfile(
                UserProfileUpsertRequest(
                    nickname: nil,
                    ageGroup: ageGroup,
                    gender: nil,
                    notificationsEnabled: nil,
                    termsAccepted: nil
                )
            )
        } catch {
#if DEBUG
            print("syncUserProfile(ageGroup) failed (non-blocking): \(error.localizedDescription)")
#endif
        }
        navigateNext = true
    }
}

#Preview {
    NavigationStack {
        AgeGroupView()
    }
}
