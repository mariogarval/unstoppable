import SwiftUI

struct GoalSelectionView: View {
    @State private var selected: Set<String> = []

    private let goals: [(title: String, emoji: String)] = [
        ("Stop planning, start doing", "\u{1F3C3}"),
        ("Stay on top of your schedule", "\u{1F4C5}"),
        ("Master your deep focus", "\u{1F3AF}"),
        ("Track every task you have", "\u{2705}"),
        ("Take a moment for yourself", "\u{2615}"),
        ("Own your daily energy", "\u{2728}"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: 4, total: 6)
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
                NavigationLink {
                    ContentView()
                } label: {
                    OnboardingPrimaryButton("Next", background: selected.isEmpty ? Color(.systemGray4) : .black, foreground: .white) { }
                }
                .accessibilityHint("Proceeds after selecting your goals.")
                .disabled(selected.isEmpty)

                Button {
                    // Skip action
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                }
                .accessibilityHint("Skips goal selection.")
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
