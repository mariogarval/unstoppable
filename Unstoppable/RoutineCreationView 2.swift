import SwiftUI

struct RoutineCreationView: View {
    @AppStorage("hasCreatedRoutine") private var hasCreatedRoutine = false
    @State private var tasks: [PendingTask] = []
    @State private var routineTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showingAddTask = false
    @State private var showingTemplates = false
    @State private var navigateHome = false
    @State private var appeared = false

    private let syncService = UserDataSyncService.shared

    private static let routineTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: Hero header
                ZStack {
                    LinearGradient(
                        colors: [Color.orange.opacity(0.12), Color.yellow.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    ConfettiDotRC(color: .orange.opacity(0.4), size: 10, x: -130, y: -20)
                    ConfettiDotRC(color: .yellow.opacity(0.6), size: 14, x: -80, y: 30)
                    ConfettiDotRC(color: .orange.opacity(0.25), size: 7, x: 100, y: -30)
                    ConfettiDotRC(color: .yellow.opacity(0.4), size: 11, x: 130, y: 20)
                    ConfettiDotRC(color: .orange.opacity(0.3), size: 8, x: 40, y: -40)

                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .yellow.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: .orange.opacity(0.4), radius: 16, y: 6)

                            Image(systemName: "sunrise.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(appeared ? 1 : 0.85)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.05), value: appeared)

                        VStack(spacing: 6) {
                            Text("Design your\nmorning ritual")
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .multilineTextAlignment(.center)

                            Text("5AM Club starts with a plan.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 36)
                }
                .frame(maxWidth: .infinity)

                // MARK: Content
                VStack(spacing: 20) {
                    if tasks.isEmpty {
                        emptyStateCards
                    } else {
                        taskListSection
                    }

                    wakeUpTimeSection

                    continueButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateHome) {
            HomeView()
        }
        .sheet(isPresented: $showingAddTask) {
            RCAddTaskSheet { title, icon, duration in
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    tasks.append(PendingTask(title: trimmed, icon: icon, duration: duration))
                }
            }
        }
        .sheet(isPresented: $showingTemplates) {
            RoutineTemplatesView(
                onSelect: { templateTasks in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        tasks = templateTasks.map { PendingTask(title: $0.title, icon: $0.icon, duration: $0.duration) }
                    }
                },
                onCreateCustom: { showingAddTask = true }
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder private var emptyStateCards: some View {
        VStack(spacing: 12) {
            Text("How do you want to start?")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button {
                    showingAddTask = true
                } label: {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        VStack(spacing: 4) {
                            Text("Build it\nyourself")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                            Text("Your rules,\nyour habits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                }

                Button {
                    showingTemplates = true
                } label: {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        VStack(spacing: 4) {
                            Text("Pick a\ntemplate")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                            Text("5AM Club,\nAtomic Habits…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Task list

    @ViewBuilder private var taskListSection: some View {
        VStack(spacing: 12) {
            taskListHeader
            taskRowList
            taskListActions
        }
    }

    @ViewBuilder private var taskListHeader: some View {
        HStack {
            Text("Your routine")
                .font(.headline)
            Spacer()
            let label = tasks.count == 1 ? "1 task" : "\(tasks.count) tasks"
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder private var taskRowList: some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.indices), id: \.self) { index in
                taskRow(at: index, onDelete: {
                    let i = index
                    withAnimation(.easeInOut(duration: 0.2)) {
                        var updated = tasks
                        updated.remove(at: i)
                        tasks = updated
                    }
                })
                if index < tasks.count - 1 {
                    Divider().padding(.leading, 66)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    @ViewBuilder private func taskRow(at index: Int, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: tasks[index].icon)
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(tasks[index].title)
                    .font(.body.weight(.medium))
                Text("\(tasks[index].duration) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(.systemGray3))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
    }

    @ViewBuilder private var taskListActions: some View {
        HStack(spacing: 10) {
            Button {
                showingAddTask = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add task")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                showingTemplates = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                    Text("Template")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Wake up time

    @ViewBuilder private var wakeUpTimeSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "alarm.fill")
                    .font(.body)
                    .foregroundStyle(.orange)
                Text("What time do you wake up?")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            DatePicker(
                "Wake up time",
                selection: $routineTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    // MARK: - CTA

    @ViewBuilder private var continueButton: some View {
        VStack(spacing: 10) {
            Button {
                savePendingTasks()
                hasCreatedRoutine = true
                navigateHome = true
            } label: {
                HStack(spacing: 10) {
                    if !tasks.isEmpty {
                        Image(systemName: "flame.fill")
                            .font(.body)
                    }
                    Text(tasks.isEmpty ? "Add at least one task" : "Start my routine")
                        .font(.body.weight(.bold))
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(.white)
                .background {
                    if tasks.isEmpty {
                        Color(.systemGray4)
                    } else {
                        LinearGradient(
                            colors: [.orange, .yellow.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: tasks.isEmpty ? .clear : .orange.opacity(0.35), radius: 10, y: 5)
            }
            .disabled(tasks.isEmpty)

            if !tasks.isEmpty {
                Text("You can edit your routine anytime from Home.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Save

    private func savePendingTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: "pendingRoutineTasks")
        }

        let request = RoutineUpsertRequest(
            routineTime: Self.routineTimeFormatter.string(from: routineTime),
            tasks: tasks.map {
                RoutineTaskPayload(
                    id: UUID().uuidString,
                    title: $0.title,
                    icon: $0.icon,
                    duration: $0.duration,
                    isCompleted: false
                )
            }
        )
        Task {
            do {
                _ = try await syncService.syncCurrentRoutine(request)
            } catch {
#if DEBUG
                print("RoutineCreationView syncCurrentRoutine failed: \(error.localizedDescription)")
#endif
            }
        }
    }
}

// MARK: - Supporting views (file-private to avoid name collisions)

private struct ConfettiDotRC: View {
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: x, y: y)
    }
}

private struct RCAddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var icon = "bed.double.fill"
    @State private var duration = 5

    let onAdd: (String, String, Int) -> Void

    private let availableIcons = [
        "bed.double.fill", "drop.fill", "brain.head.profile.fill", "iphone.slash", "fork.knife",
        "sunrise.fill", "book.fill", "figure.walk", "bolt.heart", "leaf.fill",
        "alarm.fill", "figure.run", "dumbbell.fill", "pencil.line", "sparkles"
    ]
    private let durations = [1, 2, 5, 10, 15, 20, 30, 45, 60]

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("What are you actually going to do?")) {
                    TextField("No vague goals. Be specific.", text: $title)
                }

                Section(header: Text("Icon")) {
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

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                        spacing: 12
                    ) {
                        ForEach(availableIcons, id: \.self) { name in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { icon = name }
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
                        onAdd(title, icon, duration)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canAdd)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RoutineCreationView()
    }
}

