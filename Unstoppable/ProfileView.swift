import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @State private var profileData: [String: JSONValue] = [:]
    @State private var userId: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showResetLocalConfirmation = false
    @State private var showResetAPIConfirmation = false
    @State private var isResettingAPI = false
    @State private var resetAPIErrorMessage: String?

    private let syncService = UserDataSyncService.shared

    private var isLoggedIn: Bool {
        Auth.auth().currentUser != nil
    }

    private var isDebugResetEnabled: Bool {
        Self.infoBool(
            forKey: "SHOW_SETTINGS_RESET_LOCAL_PROFILE_TEST_BUTTON",
            defaultValue: false
        )
    }

    var body: some View {
        Form {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading profile...")
                        Spacer()
                    }
                }
            } else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text("Account")) {
                    profileRow("User ID", value: userId)
                    profileRow("Status", value: isLoggedIn ? "Signed In" : "Guest")
                    if isLoggedIn, let email = Auth.auth().currentUser?.email {
                        profileRow("Email", value: email)
                    }
                }

                Section(header: Text("Personal")) {
                    profileRow("Nickname", value: profileString("nickname"))
                    profileRow("Age Group", value: profileString("ageGroup"))
                    profileRow("Gender", value: profileString("gender"))
                }

                if let goals = profileStringArray("idealDailyLifeSelections") {
                    Section(header: Text("Goals")) {
                        ForEach(goals, id: \.self) { goal in
                            Text(goal)
                        }
                    }
                }

                Section(header: Text("Preferences")) {
                    profileRow("Notifications", value: profileBool("notificationsEnabled").map { $0 ? "Enabled" : "Disabled" })
                    profileRow("Payment Option", value: profileString("paymentOption"))
                }

                Section(header: Text("Terms")) {
                    profileRow("Terms Accepted", value: profileBool("termsAccepted").map { $0 ? "Yes" : "No" })
                    profileRow("Over 16 Confirmed", value: profileBool("termsOver16Accepted").map { $0 ? "Yes" : "No" })
                    profileRow("Marketing Accepted", value: profileBool("termsMarketingAccepted").map { $0 ? "Yes" : "No" })
                }

                if isDebugResetEnabled {
                    Section(header: Text("Testing")) {
                        if !isLoggedIn {
                            Button("Reset Local Profile", role: .destructive) {
                                showResetLocalConfirmation = true
                            }
                        }
                        if isLoggedIn {
                            Button(role: .destructive) {
                                showResetAPIConfirmation = true
                            } label: {
                                if isResettingAPI {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                        Text("Resetting API Profile...")
                                    }
                                } else {
                                    Text("Reset API Profile")
                                }
                            }
                            .disabled(isResettingAPI)
                        }
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .task {
            await loadProfile()
        }
        .alert("Reset Local Profile?", isPresented: $showResetLocalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetLocalProfile()
            }
        } message: {
            Text("This clears local onboarding/profile data from UserDefaults so you can re-test initial flows.")
        }
        .alert("Reset API Profile?", isPresented: $showResetAPIConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                Task {
                    await resetAPIProfile()
                }
            }
        } message: {
            Text("This deletes your profile data from the server. You will need to complete onboarding again.")
        }
        .alert("Reset Failed", isPresented: Binding(
            get: { resetAPIErrorMessage != nil },
            set: { if !$0 { resetAPIErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resetAPIErrorMessage ?? "Please try again.")
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let bootstrap = try await syncService.fetchBootstrap()
            profileData = bootstrap.profile
            userId = bootstrap.userId
        } catch {
#if DEBUG
            print("ProfileView loadProfile failed: \(error.localizedDescription)")
#endif
            errorMessage = "Could not load profile."
        }
    }

    // MARK: - Helpers

    private func profileString(_ key: String) -> String? {
        guard let value = profileData[key] else { return nil }
        guard case .string(let str) = value else { return nil }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func profileBool(_ key: String) -> Bool? {
        guard let value = profileData[key] else { return nil }
        guard case .bool(let b) = value else { return nil }
        return b
    }

    private func profileStringArray(_ key: String) -> [String]? {
        guard let value = profileData[key] else { return nil }
        guard case .array(let arr) = value else { return nil }
        let strings = arr.compactMap { item -> String? in
            guard case .string(let s) = item else { return nil }
            return s
        }
        return strings.isEmpty ? nil : strings
    }

    private func profileRow(_ label: String, value: String?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value ?? "—")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Reset Actions

    private func resetLocalProfile() {
        StreakManager.removeUserScopedValue(forKey: "hasCompletedOnboarding")
        StreakManager.removeUserScopedValue(forKey: "hasCreatedRoutine")
        UserDefaults.standard.removeObject(forKey: "stayOnWelcomeAfterSignOut")
        UserDefaults.standard.removeObject(forKey: "guest.sync.draft.state.v1")
        StreakManager.clearLocalTestingState()
    }

    @MainActor
    private func resetAPIProfile() async {
        guard !isResettingAPI else { return }
        isResettingAPI = true
        defer { isResettingAPI = false }

        do {
            try await syncService.resetAPIProfile()
            await loadProfile()
        } catch {
#if DEBUG
            print("ProfileView resetAPIProfile failed: \(error.localizedDescription)")
#endif
            resetAPIErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Info.plist Helpers

    private static func infoBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else {
            return defaultValue
        }
        if let boolValue = value as? Bool { return boolValue }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            switch string.lowercased() {
            case "1", "true", "yes": return true
            case "0", "false", "no": return false
            default: return defaultValue
            }
        }
        return defaultValue
    }
}
