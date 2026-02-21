import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@Observable
final class AppSettings {
    enum Theme: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
    }

    var theme: Theme = .system
    var notificationsEnabled: Bool = false
    var routineTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    var hapticsEnabled: Bool = true
}

struct HomeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var settings = AppSettings()
    @State private var totalTasks: Int = 5
    @State private var showStreakBroken = false
    @State private var showMilestone = false

    private let streakManager = StreakManager.shared

    private var preferredScheme: ColorScheme? {
        switch settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTab(streakManager: streakManager, settings: settings, onTasksCountChange: { totalTasks = $0 })
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

            StatsTab(streakManager: streakManager, totalTasks: totalTasks)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
                .tag(1)

            SettingsTab(settings: settings) {
                routeToWelcomeAfterSignOut()
            }
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(2)
        }
        .tint(.orange)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            streakManager.checkAppLaunch()
            if streakManager.streakBrokenMessage != nil {
                showStreakBroken = true
            }
        }
        .alert("Streak Lost", isPresented: $showStreakBroken) {
            Button("Got it") { streakManager.streakBrokenMessage = nil }
        } message: {
            Text(streakManager.streakBrokenMessage ?? "")
        }
        .onChange(of: streakManager.milestoneMessage) { _, newValue in
            if newValue != nil { showMilestone = true }
        }
        .alert("Milestone Reached", isPresented: $showMilestone) {
            Button("Let\u{2019}s go") { streakManager.milestoneMessage = nil }
        } message: {
            Text(streakManager.milestoneMessage ?? "")
        }
    }

    @MainActor
    private func routeToWelcomeAfterSignOut() {
#if canImport(UIKit)
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else {
            dismiss()
            return
        }

        window.rootViewController = UIHostingController(rootView: WelcomeView())
        window.makeKeyAndVisible()
#else
        dismiss()
#endif
    }
}

// MARK: - Home Tab

private struct HomeTab: View {
    @State private var tasks: [RoutineTask] = [
        RoutineTask(title: "Make bed", icon: "bed.double.fill", duration: 2),
        RoutineTask(title: "Drink water", icon: "drop.fill", duration: 1),
        RoutineTask(title: "5 min meditation", icon: "brain.head.profile.fill", duration: 5),
        RoutineTask(title: "No phone 30 min", icon: "iphone.slash", duration: 30),
        RoutineTask(title: "Healthy breakfast", icon: "fork.knife", duration: 15)
    ]

    @State private var showingAddTask = false
    @State private var showingEditTime = false
    @State private var showingTemplates = false
    @State private var showingTimer = false
    @State private var routineTime: Date = Date()

    let streakManager: StreakManager
    let settings: AppSettings
    let onTasksCountChange: (Int) -> Void
    private let syncService = UserDataSyncService.shared

    private var timeString: String {
        routineTime.formatted(date: .omitted, time: .shortened)
    }

    private var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }

    private var progressFraction: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(tasks.count)
    }

    private func applyTemplate(_ templateTasks: [TemplateTask]) {
        withAnimation(.easeInOut(duration: 0.3)) {
            tasks = templateTasks.map {
                RoutineTask(title: $0.title, icon: $0.icon, duration: $0.duration)
            }
            onTasksCountChange(tasks.count)
        }
        syncRoutineSnapshot()
    }

    private func syncRoutineSnapshot() {
        let request = RoutineUpsertRequest(
            routineTime: Self.routineTimeFormatter.string(from: routineTime),
            tasks: tasks.map {
                RoutineTaskPayload(
                    id: $0.id.uuidString,
                    title: $0.title,
                    icon: $0.icon,
                    duration: $0.duration,
                    isCompleted: $0.isCompleted
                )
            }
        )

        Task {
            do {
                _ = try await syncService.syncCurrentRoutine(request)
            } catch {
#if DEBUG
                print("syncCurrentRoutine failed: \(error.localizedDescription)")
#endif
            }
        }
    }

    private static let routineTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    // Streak
                    StreakHeader(streak: streakManager.getStreakCount())
                        .padding(.top, 16)

                    if tasks.isEmpty {
                        // Empty state
                        EmptyRoutineView(
                            onBrowseTemplates: { showingTemplates = true },
                            onCreateCustom: { showingAddTask = true }
                        )
                        .padding(.top, 32)
                    } else {
                        // Morning Routine
                        VStack(spacing: 0) {
                            RoutineHeader(timeText: timeString, onEdit: { showingEditTime = true })
                                .padding(.horizontal, 20)
                                .padding(.top, 24)

                            // Tasks
                            VStack(spacing: 0) {
                                ForEach($tasks) { $task in
                                    TaskRow(task: $task,
                                            hapticsEnabled: settings.hapticsEnabled,
                                            onToggle: { completed in
                                                if completed {
                                                    streakManager.completeTask(taskID: task.id, totalTasks: tasks.count)
                                                } else {
                                                    streakManager.uncompleteTask(taskID: task.id, totalTasks: tasks.count)
                                                }
                                                syncRoutineSnapshot()
                                            },
                                            onDelete: {
                                        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                tasks.remove(at: idx)
                                                onTasksCountChange(tasks.count)
                                            }
                                            syncRoutineSnapshot()
                                        }
                                    })
                                    if task.id != tasks.last?.id {
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                            .padding(.top, 12)

                            // Progress
                            ProgressSection(
                                completed: completedCount,
                                total: tasks.count,
                                fraction: progressFraction
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 16)

                            // Start Routine
                            Button {
                                showingTimer = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "play.fill")
                                        .font(.body)
                                    Text("Do It Now")
                                        .font(.body.weight(.bold))
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.vertical, 6)
                                .foregroundStyle(.white)
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .yellow.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            // FAB
            Button {
                showingAddTask = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                    .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
            }
            .frame(width: 56, height: 56)
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
        .background(.white)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingTemplates = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.body)
                        .foregroundStyle(.orange)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet(taskCount: tasks.count) { title, icon, duration in
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    let newTask = RoutineTask(title: trimmed, icon: icon, duration: duration)
                    tasks.append(newTask)
                    onTasksCountChange(tasks.count)
                }
                syncRoutineSnapshot()
            }
        }
        .sheet(isPresented: $showingEditTime) {
            EditTimeSheet(time: $routineTime)
                .onDisappear {
                    settings.routineTime = routineTime
                    syncRoutineSnapshot()
                }
        }
        .sheet(isPresented: $showingTemplates) {
            RoutineTemplatesView(
                onSelect: { applyTemplate($0) },
                onCreateCustom: { showingAddTask = true }
            )
        }
        .fullScreenCover(isPresented: $showingTimer) {
            RoutineTimerView(
                tasks: tasks,
                hapticsEnabled: settings.hapticsEnabled
            ) { completedIDs in
                for i in tasks.indices {
                    if completedIDs.contains(tasks[i].id) {
                        tasks[i].isCompleted = true
                    }
                }
                streakManager.recordBatchCompletion(
                    completedIDs: completedIDs,
                    totalTasks: tasks.count
                )
                syncRoutineSnapshot()
            }
        }
        .onAppear {
            routineTime = settings.routineTime
            for i in tasks.indices {
                tasks[i].isCompleted = streakManager.isCompleted(taskID: tasks[i].id)
            }
            onTasksCountChange(tasks.count)
            syncRoutineSnapshot()
        }
    }
}

// MARK: - Streak Header

private struct StreakHeader: View {
    let streak: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("\u{1F525} \(streak) Day Streak")
                .font(.largeTitle.bold())

            Text(streak == 0
                 ? "Zero. Do something about it."
                 : "\(streak) days. Most people quit by now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Empty Routine View

private struct EmptyRoutineView: View {
    let onBrowseTemplates: () -> Void
    let onCreateCustom: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange.opacity(0.6))
                .padding(.bottom, 4)

            Text("No tasks. No progress.")
                .font(.title3.bold())

            Text("You didn\u{2019}t download this app to stare at\nan empty screen. Add something.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button(action: onBrowseTemplates) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                        Text("Pick a Template")
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onCreateCustom) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Build Your Own")
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 4)
                    .foregroundStyle(.orange)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.orange, lineWidth: 1.5)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Routine Header

private struct RoutineHeader: View {
    let timeText: String
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Morning Routine")
                    .font(.title2.bold())
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(timeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Task Model

struct RoutineTask: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    var duration: Int = 5
    var isCompleted = false
}

// MARK: - Task Row

private struct TaskRow: View {
    @Binding var task: RoutineTask
    let hapticsEnabled: Bool
    var onToggle: ((Bool) -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button {
            let willComplete = !task.isCompleted
            withAnimation(.easeInOut(duration: 0.2)) {
                task.isCompleted = willComplete
            }
            onToggle?(willComplete)
#if canImport(UIKit)
            if hapticsEnabled {
                if willComplete {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
#endif
        } label: {
            HStack(spacing: 14) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? Color.orange : Color(.systemGray3))

                Image(systemName: task.icon)
                    .font(.body)
                    .foregroundColor(task.isCompleted ? .secondary : Color.orange)
                    .frame(width: 24)

                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted, color: .secondary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Progress Section

private struct ProgressSection: View {
    let completed: Int
    let total: Int
    let fraction: Double

    private var percentText: String {
        let pct = total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0
        return "\(completed)/\(total) complete (\(pct)%)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(percentText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            ProgressView(value: fraction)
                .animation(.easeInOut(duration: 0.2), value: fraction)
                .tint(.orange)
                .scaleEffect(y: 1.5, anchor: .center)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Add Task Sheet

private struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var icon: String = "bed.double.fill"
    @State private var duration: Int = 5
    @State private var isPremium = false
    @State private var showPaywall = false

    let taskCount: Int
    let onAdd: (String, String, Int) -> Void

    private let availableIcons = [
        "bed.double.fill", "drop.fill", "brain.head.profile.fill", "iphone.slash", "fork.knife",
        "sunrise.fill", "book.fill", "figure.walk", "bolt.heart", "leaf.fill"
    ]

    private let durations = [1, 2, 5, 10, 15, 20, 30, 45, 60]

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title
                Section(header: Text("What are you actually going to do?")) {
                    TextField("No vague goals. Be specific.", text: $title)
                }

                // Icon preview + picker
                Section(header: Text("Icon")) {
                    // Selected icon preview
                    VStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 36))
                            .foregroundStyle(.orange)
                            .frame(width: 72, height: 72)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    // Icon grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                        ForEach(availableIcons, id: \.self) { name in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    icon = name
                                }
                            } label: {
                                Image(systemName: name)
                                    .font(.title3)
                                    .foregroundStyle(icon == name ? .white : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(icon == name ? Color.orange : Color(.systemGray5))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Duration
                Section(header: Text("Duration")) {
                    Picker("Minutes", selection: $duration) {
                        ForEach(durations, id: \.self) { mins in
                            Text(mins < 60 ? "\(mins) min" : "1 hr").tag(mins)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Add a Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if taskCount >= 5 && !isPremium {
                            showPaywall = true
                        } else {
                            onAdd(title, icon, duration)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canAdd)
                }
            }
            .sheet(isPresented: $showPaywall) {
                NavigationStack {
                    PaywallView()
                }
            }
        }
    }
}

// MARK: - Edit Time Sheet

private struct EditTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var time: Date

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("Routine Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                Spacer()
            }
            .navigationTitle("Routine Time")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Stats Tab

private struct StatsTab: View {
    let streakManager: StreakManager
    let totalTasks: Int

    @State private var selectedDay: Date?

    private var today: Date { Date() }
    private var completedToday: Int { streakManager.completedCount(on: today) }
    private var streak: Int { streakManager.getStreakCount() }
    private var longest: Int { streakManager.getLongestStreak() }
    private var weekData: (completed: Int, elapsed: Int) {
        streakManager.daysFullyCompletedThisWeek(totalTasks: totalTasks)
    }
    private var last7: [(date: Date, count: Int)] { streakManager.getWeekData() }

    private var successRate: Int {
        streakManager.successRate(totalTasks: totalTasks)
    }

    private var todaySubtitle: String {
        if totalTasks == 0 { return "Add tasks first." }
        if completedToday == totalTasks { return "All done. Respect." }
        if completedToday == 0 { return "Do better." }
        return "Not done yet."
    }

    private var streakSubtitle: String {
        if streak == 0 { return "Start now or stay at zero." }
        if streak < 3 { return "Barely started. Keep going." }
        if streak < 7 { return "Don\u{2019}t break it now." }
        return "Most people never get here."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if !streakManager.hasAnyData() && completedToday == 0 {
                    statsEmptyState
                } else {
                    statsContent
                }
            }
            .scrollIndicators(.hidden)
            .background(.white)
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Empty State

    private var statsEmptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 80)

            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 56))
                .foregroundStyle(Color(.systemGray4))

            Text("No data.")
                .font(.title2.bold())

            Text("You haven\u{2019}t done anything yet.\nComplete a routine and come back.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        VStack(spacing: 16) {
            // Today card
            StatCard(
                icon: "sun.max.fill",
                iconColor: .orange,
                title: "Today: \(completedToday)/\(totalTasks) complete",
                subtitle: todaySubtitle,
                value: totalTasks > 0
                    ? "\(Int((Double(completedToday) / Double(totalTasks)) * 100))%"
                    : "0%",
                progress: totalTasks > 0
                    ? Double(completedToday) / Double(totalTasks)
                    : 0
            )

            // Streak card
            StatCard(
                icon: "flame.fill",
                iconColor: streak > 0 ? .orange : Color(.systemGray3),
                title: "\u{1F525} \(streak) Day Streak",
                subtitle: streakSubtitle,
                value: nil,
                progress: nil
            )

            // Last 7 days chart
            WeeklyBarChart(
                data: last7,
                totalTasks: totalTasks,
                selectedDay: $selectedDay
            )

            // Insight cards grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                InsightCard(
                    icon: "calendar",
                    label: "This Week",
                    value: "\(weekData.completed)/\(weekData.elapsed)",
                    sublabel: weekData.completed == weekData.elapsed && weekData.elapsed > 0
                        ? "Perfect so far."
                        : "days completed"
                )

                InsightCard(
                    icon: "percent",
                    label: "Success Rate",
                    value: "\(successRate)%",
                    sublabel: successRate == 0
                        ? "Embarrassing."
                        : successRate == 100 ? "Flawless." : "Room to improve."
                )

                InsightCard(
                    icon: "trophy.fill",
                    label: "Best Streak",
                    value: "\(longest)",
                    sublabel: longest == 0
                        ? "No streak yet."
                        : longest == 1 ? "day. Just one." : "days"
                )

                InsightCard(
                    icon: "checkmark.seal.fill",
                    label: "Total Done",
                    value: "\(streakManager.totalTasksCompleted())",
                    sublabel: "tasks completed"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let value: String?
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let value {
                    Text(value)
                        .font(.title.bold())
                        .foregroundStyle(.orange)
                }
            }

            if let progress {
                ProgressView(value: min(progress, 1.0))
                    .tint(.orange)
                    .scaleEffect(y: 1.5, anchor: .center)
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Weekly Bar Chart

private struct WeeklyBarChart: View {
    let data: [(date: Date, count: Int)]
    let totalTasks: Int
    @Binding var selectedDay: Date?

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private let detailFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.orange)
                Text("Last 7 Days")
                    .font(.headline)
                Spacer()
            }

            // Selected day detail
            if let selected = selectedDay,
               let item = data.first(where: {
                   Calendar.current.isDate($0.date, inSameDayAs: selected)
               }) {
                HStack(spacing: 8) {
                    Text(detailFormatter.string(from: item.date))
                        .font(.caption.weight(.semibold))
                    Text("\u{2022}")
                        .foregroundStyle(.secondary)
                    Text("\(item.count)/\(totalTasks) tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDay = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Bar chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.date) { item in
                    let pct = totalTasks > 0
                        ? Double(item.count) / Double(totalTasks)
                        : 0
                    let isSelected = selectedDay.map {
                        Calendar.current.isDate($0, inSameDayAs: item.date)
                    } ?? false
                    let isToday = Calendar.current.isDateInToday(item.date)

                    VStack(spacing: 6) {
                        // Count label
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isSelected ? .orange : .secondary)
                        }

                        // Bar
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                item.count > 0
                                    ? (isSelected
                                        ? Color.orange
                                        : Color.orange.opacity(0.7))
                                    : Color(.systemGray5)
                            )
                            .frame(height: max(8, CGFloat(pct) * 120))
                            .animation(.easeInOut(duration: 0.3), value: item.count)

                        // Day label
                        Text(dayFormatter.string(from: item.date))
                            .font(.system(size: 11, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDay = isSelected ? nil : item.date
                        }
                    }
                }
            }
            .frame(height: 160)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Insight Card

private struct InsightCard: View {
    let icon: String
    let label: String
    let value: String
    let sublabel: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(value)
                .font(.title2.bold())

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)

            Text(sublabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Settings Tab (Updated)

private struct SettingsTab: View {
    @Bindable var settings: AppSettings
    let onSignedOut: () -> Void
    @State private var isSigningOut = false
    @State private var signOutErrorMessage: String?
    @State private var showPaywallTestSheet = false

    private var isPaywallTestButtonEnabled: Bool {
        Self.infoBool(
            forKey: "REVENUECAT_SHOW_SETTINGS_PAYWALL_TEST_BUTTON",
            defaultValue: false
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(AppSettings.Theme.allCases) { theme in
                            Text(theme.rawValue.capitalized).tag(theme)
                        }
                    }
                }
                Section(header: Text("Routine")) {
                    DatePicker("Routine Time", selection: $settings.routineTime, displayedComponents: .hourAndMinute)
                }
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $settings.notificationsEnabled)
                }
                Section(header: Text("Feedback")) {
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                }

                if isPaywallTestButtonEnabled {
                    Section(header: Text("Testing")) {
                        Button("Open Paywall (Test)") {
                            showPaywallTestSheet = true
                        }
                    }
                }

                Section(header: Text("Account")) {
                    Button(role: .destructive) {
                        Task {
                            await handleSignOut()
                        }
                    } label: {
                        if isSigningOut {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Signing Out...")
                            }
                        } else {
                            Text("Sign Out")
                        }
                    }
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out Failed", isPresented: Binding(
                get: { signOutErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        signOutErrorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(signOutErrorMessage ?? "Please try again.")
            }
            .sheet(isPresented: $showPaywallTestSheet) {
                NavigationStack {
                    PaywallView()
                }
            }
        }
    }

    @MainActor
    private func handleSignOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }

        do {
            try await AuthSessionManager.shared.signOut()
            onSignedOut()
        } catch {
            signOutErrorMessage = error.localizedDescription
        }
    }

    private static func infoBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else {
            return defaultValue
        }

        if let boolValue = value as? Bool {
            return boolValue
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            switch string.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return defaultValue
            }
        }
        return defaultValue
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
