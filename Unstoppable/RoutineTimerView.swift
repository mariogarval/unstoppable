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
            // Top bar: X left | "1 of N" center | "Ends time" right
            TimerTopBar(
                currentIndex: currentIndex,
                totalTasks: tasks.count,
                endTimeText: endTimeText,
                onClose: {
                    stopTimer()
                    onComplete(completedIDs)
                    dismiss()
                }
            )
            .padding(.horizontal, 24)
            .padding(.top, 20)

            if let task = currentTask {
                Spacer()

                // Timer ring fills the center
                TimerRing(
                    fraction: progressFraction,
                    icon: task.icon,
                    taskName: task.title,
                    countdown: countdownText,
                    isPaused: isPaused
                )
                .padding(.horizontal, 24)

                Spacer()

                // Done button
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
                    .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
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
    let endTimeText: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Center: progress
            Text("\(currentIndex + 1) of \(totalTasks)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .accessibilityLabel("Step \(currentIndex + 1) of \(totalTasks)")

            HStack {
                // Left: close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .accessibilityLabel("Close")

                Spacer()

                // Right: end time
                Text(endTimeText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Routine \(endTimeText)")
            }
        }
        .frame(height: 48)
    }
}

// MARK: - Timer Ring

private struct TimerRing: View {
    let fraction: Double
    let icon: String
    let taskName: String
    let countdown: String
    let isPaused: Bool

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width - 32, geometry.size.height) * 0.85
            ZStack {
                // Track circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: diameter, height: diameter)

                // Progress arc
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(
                            colors: [.yellow, .orange, .orange],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter, height: diameter)
                    .animation(.easeInOut(duration: 0.35), value: fraction)

                // Tip glow dot — uses same -90° start as the arc
                if fraction > 0.01 {
                    let tipAngle = Angle.degrees(360 * fraction - 90)
                    let r = diameter / 2
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 18, height: 18)
                        .shadow(color: .orange.opacity(0.6), radius: 6)
                        .offset(
                            x: r * cos(tipAngle.radians),
                            y: r * sin(tipAngle.radians)
                        )
                        .animation(.easeInOut(duration: 0.35), value: fraction)
                }

                // Center content: icon, task name, countdown, label
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.orange)
                        .padding(.bottom, 4)

                    Text(taskName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(countdown)
                        .font(.system(size: 72, weight: .black))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: countdown)

                    Text(isPaused ? "PAUSED" : "remaining")
                        .font(.system(size: 14, weight: isPaused ? .semibold : .regular))
                        .foregroundColor(isPaused ? .orange : .gray)
                        .padding(.top, -4)
                }
                .frame(width: diameter * 0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(color)
                    )

                Text(label)
                    .font(.system(size: 15, weight: .semibold))
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
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.width, height: piece.height)
                    .rotationEffect(.degrees(piece.rotation))
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
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Text("Took you long enough.")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
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
                        .frame(maxWidth: .infinity, minHeight: 52)
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
        return (0..<50).map { i in
            let size = CGFloat.random(in: 6...14)
            return ConfettiPiece(
                id: i,
                color: colors[i % colors.count],
                width: size * CGFloat.random(in: 0.5...1.5),
                height: size,
                rotation: Double.random(in: 0...360),
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
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
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
