import SwiftUI

struct AgeGroupView: View {
    @State private var navigateNext = false
    private let syncService = UserDataSyncService.shared

    private let ageRanges = [
        "20 ~ 24",
        "25 ~ 29",
        "30 ~ 34",
        "35 ~ 39",
        "40 ~ 44",
        "45 and above",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: 5, total: 6)
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
                            syncAgeGroup(range)
                            navigateNext = true
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
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
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

    private func syncAgeGroup(_ ageGroup: String) {
        Task {
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
                print("syncUserProfile(ageGroup) failed: \(error.localizedDescription)")
#endif
            }
        }
    }
}

#Preview {
    NavigationStack {
        AgeGroupView()
    }
}
