import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RoutineTimerView: View {
    @Environment(\.dismiss) private var dismiss

    let tasks: [RoutineTask]
    let hapticsEnabled: Bool
    let onComplete: (Set<UUID>) -> Void

    @State private var currentIndex = 0
    @State private var remainingSeconds: Int = 0
    @State private var isPaused = false
    @State private var completedIDs: Set<UUID> = []
    @State private var isFinished = false
    @State private var timer: Timer?

    private var currentTask: RoutineTask? {
        guard currentIndex < tasks.count else { return nil }
        return tasks[currentIndex]
    }

    private var totalDurationSeconds: Int {
        tasks.dropFirst(currentIndex).reduce(0) { $0 + $1.duration * 60 }
        - ((currentTask?.duration ?? 0) * 60 - remainingSeconds)
    }

    private var endTimeText: String {
        let end = Calendar.current.date(byAdding: .second, value: totalDurationSeconds, to: .now) ?? .now
        return "Ends " + end.formatted(date: .omitted, time: .shortened)
    }

    private var progressFraction: Double {
        guard let task = currentTask, task.duration > 0 else { return 0 }
        let total = task.duration * 60
        return 1.0 - (Double(remainingSeconds) / Double(total))
    }

    private var countdownText: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var body: some View {
        if isFinished {
            CompletionView(
                streak: completedIDs.count == tasks.count ? 1 : 0,
                tasksCompleted: completedIDs.count,
                totalTasks: tasks.count
            ) {
                onComplete(completedIDs)
                dismiss()
            }
        } else {
            timerContent
        }
    }

    // MARK: - Timer Content

    private var timerContent: some View {
        VStack(spacing: 0) {
            TimerTopBar(
                currentIndex: currentIndex,
                totalTasks: tasks.count,
                onClose: {
                    stopTimer()
                    onComplete(completedIDs)
                    dismiss()
                }
            )
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .accessibilityElement(children: .combine)

            // endTimeText below top bar, centered
            Text(endTimeText)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Routine ends at \(endTimeText.replacingOccurrences(of: "Ends ", with: ""))")

            Spacer()

            if let task = currentTask {
                // Title of current step above ring
                Text(task.title)
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    .padding(.bottom, 12)
                    .accessibilityLabel("Current task: \(task.title)")

                // TimerRing with increased height and centered content in VStack with Spacers
                VStack(spacing: 0) {
                    Spacer()
                    TimerRing(
                        fraction: progressFraction,
                        icon: task.icon,
                        countdown: countdownText
                    )
                    .frame(height: 400)
                    .accessibilityElement(children: .combine)
                    Spacer()
                }
                .frame(maxWidth: .infinity)

                // "Done" button below TimerRing above controls
                Button(action: {
                    completeCurrentTask()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Done")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.green.opacity(0.6), radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)
                .padding(.bottom, 24)
                .accessibilityLabel("Complete current task")

            }

            TimerControls(
                isPaused: isPaused,
                onPause: { togglePause() },
                onSkip: { skipCurrentTask() }
            )
            .padding(.bottom, 48)
            .padding(.horizontal, 40)
        }
        .background(.white)
        .onAppear { startTask(at: 0) }
        .onDisappear { stopTimer() }
    }

    // MARK: - Timer Logic

    private func startTask(at index: Int) {
        guard index < tasks.count else {
            isFinished = true
            return
        }
        currentIndex = index
        remainingSeconds = tasks[index].duration * 60
        isPaused = false
        startTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !isPaused else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                completeCurrentTask()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func togglePause() {
        isPaused.toggle()
#if canImport(UIKit)
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
#endif
    }

    private func completeCurrentTask() {
        if let task = currentTask {
            completedIDs.insert(task.id)
        }
#if canImport(UIKit)
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
#endif
        advanceToNext()
    }

    private func skipCurrentTask() {
#if canImport(UIKit)
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
#endif
        advanceToNext()
    }

    private func advanceToNext() {
        stopTimer()
        let next = currentIndex + 1
        if next >= tasks.count {
            withAnimation(.easeInOut(duration: 0.4)) {
                isFinished = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                startTask(at: next)
            }
        }
    }
}

// MARK: - Top Bar

private struct TimerTopBar: View {
    let currentIndex: Int
    let totalTasks: Int
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Close button with larger tap area, background, shadow
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 32, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
            )
            .accessibilityLabel("Close")

            Spacer()

            // Right aligned progress text only
            Text("\(currentIndex + 1) of \(totalTasks)")
                .font(.system(size: 20, weight: .semibold, design: .default))
                .foregroundColor(.primary)
                .accessibilityLabel("Step \(currentIndex + 1) of \(totalTasks)")
        }
        .frame(height: 44)
    }
}

// MARK: - Timer Ring

private struct TimerRing: View {
    let fraction: Double
    let icon: String
    let countdown: String

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height * 0.6)
            ZStack {
                // Background blur/glass effect behind ring
                RoundedRectangle(cornerRadius: diameter * 0.5)
                    .fill(.ultraThinMaterial)
                    .frame(width: diameter + 40, height: diameter + 40)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)

                // Track circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: diameter, height: diameter)

                // Progress circle
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter, height: diameter)
                    .animation(.easeInOut(duration: 0.35), value: fraction)

                // Center content without title
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.orange)

                    Text(countdown)
                        .font(.system(size: 72, weight: .black, design: .default))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text("remaining")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                        .padding(.top, -4)
                }
                .frame(width: diameter * 0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.35), value: countdown)
        }
    }
}

// MARK: - Timer Controls

private struct TimerControls: View {
    let isPaused: Bool
    let onPause: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 48) {
            ControlButton(
                icon: isPaused ? "play.fill" : "pause.fill",
                label: isPaused ? "Go" : "Pause",
                color: .primary,
                action: onPause,
                hapticsType: .impactLight
            )

            ControlButton(
                icon: "forward.fill",
                label: "Skip",
                color: .primary,
                action: onSkip,
                hapticsType: .impactMedium
            )
        }
    }
}

private enum HapticType {
    case impactLight
    case impactMedium
    case notificationSuccess
}

private struct ControlButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    let hapticsType: HapticType

    var body: some View {
        Button(action: {
            Task { await triggerHaptics() }
            action()
        }) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 32, weight: .semibold, design: .default))
                            .foregroundColor(color)
                    )

                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func triggerHaptics() async {
#if canImport(UIKit)
        guard UIDevice.current.userInterfaceIdiom == .phone || UIDevice.current.userInterfaceIdiom == .pad else { return }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if windowScene.activationState == .foregroundActive {
                switch hapticsType {
                case .impactLight:
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                case .impactMedium:
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                case .notificationSuccess:
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
#endif
    }
}

// MARK: - Completion View

private struct CompletionView: View {
    let streak: Int
    let tasksCompleted: Int
    let totalTasks: Int
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Confetti particles
            ForEach(confettiPieces) { piece in
                Circle()
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size)
                    .offset(x: piece.x, y: appeared ? piece.endY : piece.startY)
                    .opacity(appeared ? 0 : 1)
                    .animation(
                        .easeOut(duration: piece.duration)
                            .delay(piece.delay),
                        value: appeared
                    )
            }

            // Content
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Text("Took you long enough.")
                    .font(.largeTitle.bold())
                    .opacity(appeared ? 1 : 0)

                if streak > 0 {
                    Text("\(streak) day streak \u{1F525}")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .opacity(appeared ? 1 : 0)
                }

                Text(tasksCompleted == totalTasks
                     ? "All \(totalTasks) tasks. No excuses made."
                     : "\(tasksCompleted)/\(totalTasks) done. Finish what you start next time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)

                Text("Same time tomorrow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                Button(action: onDismiss) {
                    Text("Dismissed")
                        .font(.body.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            confettiPieces = generateConfetti()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func generateConfetti() -> [ConfettiPiece] {
        let colors: [Color] = [.orange, .yellow, .green, .blue, .pink, .purple, .red]
        return (0..<40).map { i in
            ConfettiPiece(
                id: i,
                color: colors[i % colors.count],
                size: CGFloat.random(in: 6...14),
                x: CGFloat.random(in: -180...180),
                startY: CGFloat.random(in: -400 ... -200),
                endY: CGFloat.random(in: 400...800),
                duration: Double.random(in: 2.0...3.5),
                delay: Double.random(in: 0...0.5)
            )
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id: Int
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let duration: Double
    let delay: Double
}

#Preview {
    RoutineTimerView(
        tasks: [
            RoutineTask(title: "Make bed", icon: "bed.double.fill", duration: 1),
            RoutineTask(title: "Drink water", icon: "drop.fill", duration: 1),
            RoutineTask(title: "Meditation", icon: "brain.head.profile.fill", duration: 2)
        ],
        hapticsEnabled: true,
        onComplete: { _ in }
    )
}

