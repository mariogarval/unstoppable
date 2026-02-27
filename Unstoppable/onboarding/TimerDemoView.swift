import SwiftUI

struct TimerDemoView: View {
    var body: some View {
        VStack(spacing: 0) {
            ThemedProgressBar.light(step: OnboardingProgress.timerDemo, total: OnboardingProgress.totalSteps)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            Spacer()

            Text("Hit play.\nNo distractions.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

            TimerMockup()
                .padding(.horizontal, 40)

            Spacer()

            NavigationLink {
                SocialProofView()
            } label: {
                Text("Next")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityHint("Proceeds to social proof.")
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

// MARK: - Shared onboarding components

struct OnboardingStepProgressBar: View {
    let step: Int
    let total: Int
    var tintColor: Color = .orange
    var trackColor: Color = Color.white.opacity(0.2)
    var labelColor: Color = .white.opacity(0.5)

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1...total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= step ? tintColor : trackColor)
                        .frame(height: 4)
                }
            }
            Text("\(step)/\(total)")
                .font(.caption)
                .foregroundStyle(labelColor)
        }
    }
}

struct OnboardingBackButton: View {
    var color: Color = .white
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Timer mockup

private struct TimerMockup: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("\u{1F4A7}")
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Drink water")
                    .font(.subheadline.weight(.semibold))
                Text("1 min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: 0.97)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("00:02")
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 180, height: 180)
            .padding(.vertical, 24)

            HStack(spacing: 32) {
                TimerControl(icon: "pause.circle.fill", label: "Pause", color: .primary)
                TimerControl(icon: "checkmark.circle.fill", label: "Complete", color: .green)
                TimerControl(icon: "forward.circle.fill", label: "Skip", color: .primary)
            }
            .padding(.bottom, 20)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

private struct TimerControl: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 44, minHeight: 44)
    }
}

#Preview {
    NavigationStack {
        TimerDemoView()
    }
}
