import SwiftUI

struct RoutinePreviewView: View {
    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: 1, total: 6)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 10) {
                Text("Build your\nwar plan")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("5AM Club \u{2022} Atomic Habits \u{2022} Deep Work")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 32)

            RoutineMockup()
                .padding(.horizontal, 40)

            Spacer()

            NavigationLink(destination: TimerDemoView()) {
                Text("Next")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityHint("Proceeds to the timer demo.")
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
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

private struct RoutineMockup: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Morning Routine")
                    .font(.headline)
                Text("07:00am ~ 07:30am")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                MockupTaskRow(emoji: "\u{1F32C}\u{FE0F}", title: "Deep breathing", duration: "1 min")
                MockupTaskRow(emoji: "\u{1F6CF}\u{FE0F}", title: "Make the bed", duration: "1 min")
                MockupTaskRow(emoji: "\u{1F4A7}", title: "Drink water", duration: "1 min")
                MockupTaskRow(emoji: "\u{1F4DD}", title: "Morning Journaling", duration: "10 min")
            }

            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .padding(.vertical, 16)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

private struct MockupTaskRow: View {
    let emoji: String
    let title: String
    let duration: String

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(title)
                .font(.subheadline.weight(.medium))

            Spacer()

            Text(duration)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        RoutinePreviewView()
    }
}
