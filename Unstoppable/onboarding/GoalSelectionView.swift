import SwiftUI

struct GoalSelectionView: View {
    @State private var selected: Set<String> = []
    @State private var navigateNext = false
    @State private var isSavingProfile = false
    @State private var syncErrorMessage: String?
    @State private var didHydrateSelections = false
    @State private var hasUserInteracted = false

    private let goals: [(title: String, emoji: String)] = [
        ("Join the 5AM Club", "\u{23F0}"),
        ("Build atomic habits", "\u{1F504}"),
        ("Master deep work", "\u{1F3AF}"),
        ("Change my life", "\u{1F525}"),
        ("Own my mornings", "\u{2600}\u{FE0F}"),
        ("Discipline over motivation", "\u{1F4AA}"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]
    private let syncService = UserDataSyncService.shared

    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: 4, total: 7)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("Your ideal daily life?")
                    .font(.title.bold())
                Text("I'll suggest a routine just for you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 28)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(goals, id: \.title) { goal in
                    GoalCard(
                        title: goal.title,
                        emoji: goal.emoji,
                        isSelected: selected.contains(goal.title)
                    ) {
                        hasUserInteracted = true
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selected.contains(goal.title) {
                                selected.remove(goal.title)
                            } else {
                                selected.insert(goal.title)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        await continueToNotifications(saveSelection: true)
                    }
                } label: {
                    Text(isSavingProfile ? "Saving..." : "Next")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 4)
                        .foregroundStyle(.white)
                        .background(selected.isEmpty ? Color(.systemGray4) : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selected.isEmpty || isSavingProfile)
                .accessibilityHint("Proceeds after selecting your goals.")

                Button {
                    Task {
                        await continueToNotifications(saveSelection: false)
                    }
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                }
                .disabled(isSavingProfile)
                .accessibilityHint("Skips goal selection.")

                if let syncErrorMessage {
                    Text(syncErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 20)
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
        .task {
            await hydrateSelectionsIfNeeded()
        }
    }

    @MainActor
    private func continueToNotifications(saveSelection: Bool) async {
        isSavingProfile = true
        syncErrorMessage = nil
        defer { isSavingProfile = false }

        let orderedSelections = goals.map(\.title).filter { selected.contains($0) }
        let selectionsToPersist = saveSelection ? orderedSelections : []

        do {
            _ = try await syncService.syncUserProfile(
                UserProfileUpsertRequest(idealDailyLifeSelections: selectionsToPersist)
            )
        } catch {
            syncErrorMessage = "Couldn't save this preference. Continuing anyway."
#if DEBUG
            print("syncUserProfile(idealDailyLifeSelections) failed (non-blocking): \(error.localizedDescription)")
#endif
        }

        navigateNext = true
    }

    @MainActor
    private func hydrateSelectionsIfNeeded() async {
        guard !didHydrateSelections else { return }
        didHydrateSelections = true

        do {
            let bootstrap = try await syncService.fetchBootstrap()
            let savedSelections = profileStringArray("idealDailyLifeSelections", from: bootstrap.profile)
            guard !savedSelections.isEmpty else { return }
            guard !hasUserInteracted else { return }

            let allowedGoals = Set(goals.map(\.title))
            let hydratedSelections = savedSelections.filter { allowedGoals.contains($0) }
            selected = Set(hydratedSelections)
#if DEBUG
            print("GoalSelectionView hydrated idealDailyLifeSelections raw=\(savedSelections) filtered=\(hydratedSelections)")
#endif
        } catch {
#if DEBUG
            print("GoalSelectionView hydrateSelectionsIfNeeded failed: \(error.localizedDescription)")
#endif
        }
    }

    private func profileStringArray(_ key: String, from profile: [String: JSONValue]) -> [String] {
        guard let value = profile[key] else { return [] }
        guard case .array(let values) = value else { return [] }
        return values.compactMap {
            guard case .string(let str) = $0 else { return nil }
            return str
        }
    }
}

private struct GoalCard: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 28))
                Text(title)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.yellow.opacity(0.15) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? .yellow : .clear, lineWidth: 2)
            )
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

#Preview {
    NavigationStack {
        GoalSelectionView()
    }
}
