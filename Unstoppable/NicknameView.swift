import SwiftUI

struct NicknameView: View {
    @State private var nickname = ""
    @State private var appeared = false
    @State private var navigateNext = false
    @FocusState private var isFocused: Bool

    private let syncService = UserDataSyncService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("What do they\ncall you?")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                Text("Real name, nickname, call sign. Just pick one.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(.easeOut(duration: 0.4), value: appeared)

            // Field label
            Text("Nickname")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 24)

            // Text field with modern styling
            HStack(spacing: 8) {
                TextField("Enter your nickname", text: $nickname)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .focused($isFocused)
                    .submitLabel(.done)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary.opacity(0.2) : Color.accentColor,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                }
            )
            .onTapGesture { isFocused = true }
            .accessibilityLabel("Nickname")

            // Helper / validation
            if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Type something. It takes two seconds.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            Spacer()

            // Next button
            Button {
                continueToAgeGroup()
            } label: {
                Text("Next")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(nickname.isEmpty ? .white.opacity(0.6) : .white)
                    .background(nickname.isEmpty ? Color(.systemGray4) : Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(nickname.isEmpty)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .onAppear { appeared = true }
        .navigationDestination(isPresented: $navigateNext) {
            AgeGroupView()
        }
    }

    private func continueToAgeGroup() {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        navigateNext = true
        Task {
            do {
                _ = try await syncService.syncUserProfile(
                    UserProfileUpsertRequest(
                        nickname: trimmed,
                        ageGroup: nil,
                        gender: nil,
                        notificationsEnabled: nil,
                        termsAccepted: nil
                    )
                )
            } catch {
#if DEBUG
                print("syncUserProfile(nickname) failed: \(error.localizedDescription)")
#endif
            }
        }
    }
}

#Preview {
    NavigationStack {
        NicknameView()
    }
}
