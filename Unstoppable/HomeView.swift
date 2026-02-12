import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

@Observable
final class CompletionHistory {
    private(set) var byDay: [Date: Set<UUID>] = [:]

    private func dayKey(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    func set(_ completed: Bool, taskID: UUID, on date: Date = Date()) {
        let key = dayKey(for: date)
        var set = byDay[key] ?? []
        if completed { set.insert(taskID) } else { set.remove(taskID) }
        byDay[key] = set
    }

    func isCompleted(taskID: UUID, on date: Date = Date()) -> Bool {
        let key = dayKey(for: date)
        return byDay[key]?.contains(taskID) ?? false
    }

    func completedCount(on date: Date = Date()) -> Int {
        let key = dayKey(for: date)
        return byDay[key]?.count ?? 0
    }

    func streak(upTo date: Date = Date()) -> Int {
        var count = 0
        var day = dayKey(for: date)
        while true {
            if let set = byDay[day], !set.isEmpty {
                count += 1
                if let prev = Calendar.current.date(byAdding: .day, value: -1, to: day) {
                    day = prev
                } else { break }
            } else { break }
        }
        return count
    }

    func lastNDays(_ n: Int, endingAt date: Date = Date()) -> [(date: Date, count: Int)] {
        var result: [(Date, Int)] = []
        let end = dayKey(for: date)
        for offset in stride(from: n - 1, through: 0, by: -1) {
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: end)!
            result.append((d, completedCount(on: d)))
        }
        return result
    }
}

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
    @State private var selectedTab = 0
    @State private var history = CompletionHistory()
    @State private var settings = AppSettings()
    @State private var totalTasks: Int = 5

    private var preferredScheme: ColorScheme? {
        switch settings.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTab(history: history, settings: settings, onTasksCountChange: { totalTasks = $0 })
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

            StatsTab(history: history, settings: settings, totalTasks: totalTasks)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
                .tag(1)

            SettingsTab(settings: settings)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(2)
        }
        .tint(.orange)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(preferredScheme)
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

    let history: CompletionHistory
    let settings: AppSettings
    let onTasksCountChange: (Int) -> Void

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
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    // Streak
                    StreakHeader(streak: history.streak(upTo: Date()))
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
                                            onToggle: { completed in history.set(completed, taskID: task.id) },
                                            onDelete: {
                                        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                tasks.remove(at: idx)
                                                history.set(false, taskID: task.id)
                                                onTasksCountChange(tasks.count)
                                            }
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
                    history.set(false, taskID: newTask.id)
                    onTasksCountChange(tasks.count)
                }
            }
        }
        .sheet(isPresented: $showingEditTime) {
            EditTimeSheet(time: $routineTime)
                .onDisappear {
                    settings.routineTime = routineTime
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
                        history.set(true, taskID: tasks[i].id)
                    }
                }
            }
        }
        .onAppear {
            routineTime = settings.routineTime
            for i in tasks.indices {
                tasks[i].isCompleted = history.isCompleted(taskID: tasks[i].id)
            }
            onTasksCountChange(tasks.count)
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

// MARK: - Stats Tab with live stats

private struct StatsTab: View {
    let history: CompletionHistory
    let settings: AppSettings
    let totalTasks: Int

    var body: some View {
        VStack(spacing: 16) {
            let today = Date()
            let completedToday = history.completedCount(on: today)
            let streak = history.streak(upTo: today)

            StatCard(title: "Today", value: "\(completedToday)/\(totalTasks)", systemImage: "sun.max.fill")
            StatCard(title: "Streak", value: "\(streak) days", systemImage: "flame.fill")

            VStack(alignment: .leading, spacing: 8) {
                Text("Last 7 days").font(.headline)
                Chart(history.lastNDays(7), id: \.date) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Completed", item.count)
                    )
                    .foregroundStyle(.orange)
                    .annotation(position: .top, alignment: .center) {
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartYScale(domain: 0...max(1, totalTasks))
                .frame(height: 180)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
            Spacer()
        }
        .padding()
        .background(.white)
    }
}

// MARK: - Stat Card View

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.weight(.bold))
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Settings Tab (Updated)

private struct SettingsTab: View {
    @Bindable var settings: AppSettings

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
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}

