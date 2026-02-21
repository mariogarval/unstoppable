import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    @State private var navigateNext = false
    @State private var bellBounce = false
    @State private var isRequestingPermission = false
    @State private var isSavingProfile = false
    @State private var syncErrorMessage: String?
    private let syncService = UserDataSyncService.shared

    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: 6, total: 6)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(.yellow.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, value: bellBounce)
            }
            .padding(.bottom, 32)

            // Headline
            Text("You will forget.\nWe won\u{2019}t.")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            // Subheading
            Text("We\u{2019}ll remind you. A lot.\nThat\u{2019}s the point.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Notification preview mockup
            NotificationPreview()
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

            // CTA
            VStack(spacing: 12) {
                Button {
                    requestNotificationPermission()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.body)
                        Text("Hold me accountable")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityHint("Requests notification permission.")
                .disabled(isRequestingPermission || isSavingProfile)

                Button {
                    Task {
                        await continueWithNotifications(enabled: false)
                    }
                } label: {
                    Text("I\u{2019}ll risk it alone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                }
                .accessibilityHint("Skips enabling notifications.")
                .disabled(isRequestingPermission || isSavingProfile)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            if let syncErrorMessage {
                Text(syncErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .background(.white)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                OnboardingBackButton(color: .primary)
            }
        }
        .navigationDestination(isPresented: $navigateNext) {
            BeforeAfterView()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                bellBounce.toggle()
            }
        }
    }

    private func requestNotificationPermission() {
        isRequestingPermission = true
        syncErrorMessage = nil
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            DispatchQueue.main.async {
                isRequestingPermission = false
                Task {
                    await continueWithNotifications(enabled: granted)
                }
            }
        }
    }

    @MainActor
    private func continueWithNotifications(enabled: Bool) async {
        isSavingProfile = true
        syncErrorMessage = nil
        defer { isSavingProfile = false }

        do {
            _ = try await syncService.syncUserProfile(
                UserProfileUpsertRequest(
                    nickname: nil,
                    ageGroup: nil,
                    gender: nil,
                    notificationsEnabled: enabled,
                    termsAccepted: nil
                )
            )
            navigateNext = true
        } catch {
            syncErrorMessage = "Could not save notification preference. Please try again."
#if DEBUG
            print("syncUserProfile(notifications) failed: \(error.localizedDescription)")
#endif
        }
    }
}

// MARK: - Notification preview mockup

private struct NotificationPreview: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "flame.fill")
                        .font(.callout)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("UNSTOPPABLE")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("now")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text("Get up. Your routine is waiting.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

#Preview {
    NavigationStack {
        NotificationPermissionView()
    }
}
