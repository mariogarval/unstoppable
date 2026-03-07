import SwiftUI
import FirebaseAuth

// MARK: - Day Record

struct DayRecord: Codable {
    var completed: Int
    var total: Int
}

// MARK: - Streak Manager

@Observable
final class StreakManager {
    static let shared = StreakManager()
    private static let guestUserID = "guest-local"

    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0
    var streakBrokenMessage: String?
    var milestoneMessage: String?

    // In-memory: today's individual task tracking
    private var todayCompletedIDs: Set<UUID> = []

    // Persisted: daily completion records keyed by "yyyy-MM-dd"
    private var dailyRecords: [String: DayRecord] = [:]
    private var lastQualifiedDate: String = ""
    private var activeStorageScope = guestUserID

    private let defaults = UserDefaults.standard
    private let syncService = UserDataSyncService.shared
    private static let keyPrefix = "streak.v2"
    private var didHydrateFromBootstrap = false

    private init() {
        activeStorageScope = Self.storageScopeUserID()
        load()
    }

    // MARK: - App Launch

    /// Call once at app launch. Checks if user missed yesterday and resets streak.
    func checkAppLaunch() {
        refreshStorageScopeIfNeeded()

        let today = Self.dateString(for: Date())
        let yesterday = Self.dateString(for: Self.yesterday())

        if lastQualifiedDate == today || lastQualifiedDate == yesterday {
            // Streak still alive (either already qualified today or yesterday was qualified)
        } else if !lastQualifiedDate.isEmpty && currentStreak > 0 {
            currentStreak = 0
            streakBrokenMessage = "Streak broken. Back to zero."
            save()
        }
    }

    // MARK: - Task Completion

    func completeTask(taskID: UUID, totalTasks: Int) {
        refreshStorageScopeIfNeeded()
        todayCompletedIDs.insert(taskID)
        updateToday(totalTasks: totalTasks)
    }

    func uncompleteTask(taskID: UUID, totalTasks: Int) {
        refreshStorageScopeIfNeeded()
        todayCompletedIDs.remove(taskID)
        updateToday(totalTasks: totalTasks)
    }

    func isCompleted(taskID: UUID) -> Bool {
        refreshStorageScopeIfNeeded()
        return todayCompletedIDs.contains(taskID)
    }

    /// Batch-record completions from RoutineTimerView
    func recordBatchCompletion(completedIDs: Set<UUID>, totalTasks: Int) {
        refreshStorageScopeIfNeeded()
        todayCompletedIDs.formUnion(completedIDs)
        updateToday(totalTasks: totalTasks)
    }

    func refreshStorageScopeIfNeeded() {
        let scope = Self.storageScopeUserID()
        guard scope != activeStorageScope else { return }

        activeStorageScope = scope
        todayCompletedIDs = []
        streakBrokenMessage = nil
        milestoneMessage = nil
        didHydrateFromBootstrap = false
        load()
    }

    static func clearLocalTestingState() {
        let defaults = UserDefaults.standard
        let legacyKeys = [
            "streak.dailyRecords",
            "streak.current",
            "streak.longest",
            "streak.lastQualified"
        ]

        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("\(keyPrefix).") || key.hasPrefix("pendingRoutineTasks.") {
                defaults.removeObject(forKey: key)
            }
        }

        legacyKeys.forEach { defaults.removeObject(forKey: $0) }

        let manager = shared
        manager.todayCompletedIDs = []
        manager.dailyRecords = [:]
        manager.currentStreak = 0
        manager.longestStreak = 0
        manager.lastQualifiedDate = ""
        manager.streakBrokenMessage = nil
        manager.milestoneMessage = nil
        manager.didHydrateFromBootstrap = false
        manager.activeStorageScope = storageScopeUserID()
    }

    // MARK: - Queries

    func getStreakCount() -> Int { currentStreak }
    func getLongestStreak() -> Int { longestStreak }

    func getTodayProgress(totalTasks: Int) -> (completed: Int, total: Int) {
        refreshStorageScopeIfNeeded()
        return (todayCompletedIDs.count, totalTasks)
    }

    func completedCount(on date: Date) -> Int {
        refreshStorageScopeIfNeeded()
        return dailyRecords[Self.dateString(for: date)]?.completed ?? 0
    }

    func getWeekData() -> [(date: Date, count: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            return (day, completedCount(on: day))
        }
    }

    func daysFullyCompletedThisWeek(totalTasks: Int) -> (completed: Int, elapsed: Int) {
        guard totalTasks > 0 else { return (0, 0) }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1 = Sunday
        guard let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: today) else {
            return (0, 0)
        }
        var completed = 0
        var elapsed = 0
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: startOfWeek),
                  day <= today else { break }
            elapsed += 1
            if let record = dailyRecords[Self.dateString(for: day)],
               record.completed >= totalTasks {
                completed += 1
            }
        }
        return (completed, elapsed)
    }

    func successRate(totalTasks: Int) -> Int {
        refreshStorageScopeIfNeeded()
        guard totalTasks > 0 else { return 0 }
        let active = dailyRecords.values.filter { $0.total > 0 }
        guard !active.isEmpty else { return 0 }
        let perfect = active.filter { $0.completed >= $0.total }.count
        return Int((Double(perfect) / Double(active.count)) * 100)
    }

    func totalTasksCompleted() -> Int {
        refreshStorageScopeIfNeeded()
        return dailyRecords.values.reduce(0) { $0 + $1.completed }
    }

    func hasAnyData() -> Bool {
        refreshStorageScopeIfNeeded()
        return dailyRecords.values.contains { $0.completed > 0 }
    }

    // MARK: - Private

    private func updateToday(totalTasks: Int) {
        let today = Self.dateString(for: Date())
        let completed = todayCompletedIDs.count
        dailyRecords[today] = DayRecord(completed: completed, total: totalTasks)

        // Check streak qualification: >=80% completion
        let pct = totalTasks > 0 ? Double(completed) / Double(totalTasks) : 0
        if pct >= 0.8 && lastQualifiedDate != today {
            let yesterday = Self.dateString(for: Self.yesterday())
            if lastQualifiedDate == yesterday || currentStreak == 0 {
                currentStreak += 1
            } else {
                currentStreak = 1 // gap existed, start fresh
            }
            lastQualifiedDate = today
            longestStreak = max(longestStreak, currentStreak)
            checkMilestones()
        }
        save()
        syncTodayProgress(date: today, completed: completed, total: totalTasks)
    }

    private func syncTodayProgress(date: String, completed: Int, total: Int) {
        let completedTaskIds = todayCompletedIDs.map(\.uuidString).sorted()
        let request = DailyProgressUpsertRequest(
            date: date,
            completed: completed,
            total: total,
            completedTaskIds: completedTaskIds
        )

        Task {
            do {
                _ = try await syncService.syncDailyProgress(request)
            } catch {
#if DEBUG
                print("syncDailyProgress failed: \(error.localizedDescription)")
#endif
            }
        }
    }

    func hydrateFromBootstrapIfNeeded(streak: [String: JSONValue]) {
        refreshStorageScopeIfNeeded()
        guard !didHydrateFromBootstrap else { return }
        didHydrateFromBootstrap = true

        // Preserve actively-used local state; this path is for fresh install/new device restores.
        guard dailyRecords.isEmpty, currentStreak == 0, longestStreak == 0, lastQualifiedDate.isEmpty else {
            return
        }

        let remoteCurrent = Self.intValue(streak["currentStreak"]) ?? 0
        let remoteLongest = Self.intValue(streak["longestStreak"]) ?? 0
        let remoteLastQualifiedDate = Self.stringValue(streak["lastQualifiedDate"]) ?? ""
        guard remoteCurrent > 0 || remoteLongest > 0 || !remoteLastQualifiedDate.isEmpty else {
            return
        }

        currentStreak = max(0, remoteCurrent)
        longestStreak = max(currentStreak, remoteLongest)
        lastQualifiedDate = remoteLastQualifiedDate
        save()
    }

    private func checkMilestones() {
        switch currentStreak {
        case 7:
            milestoneMessage = "Week Warrior \u{1F525}"
        case 30:
            milestoneMessage = "Monthly Grinder \u{1F4AA}"
        case 90:
            milestoneMessage = "Quarter Champion \u{1F451}"
        default:
            break
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(dailyRecords) {
            defaults.set(data, forKey: scopedKey("dailyRecords"))
        }
        defaults.set(currentStreak, forKey: scopedKey("current"))
        defaults.set(longestStreak, forKey: scopedKey("longest"))
        defaults.set(lastQualifiedDate, forKey: scopedKey("lastQualified"))
        syncStreakSnapshot()
    }

    private func load() {
        dailyRecords = [:]
        currentStreak = 0
        longestStreak = 0
        lastQualifiedDate = ""

        if let data = defaults.data(forKey: scopedKey("dailyRecords")),
           let records = try? JSONDecoder().decode([String: DayRecord].self, from: data) {
            dailyRecords = records
        }
        currentStreak = defaults.integer(forKey: scopedKey("current"))
        longestStreak = defaults.integer(forKey: scopedKey("longest"))
        lastQualifiedDate = defaults.string(forKey: scopedKey("lastQualified")) ?? ""
    }

    private func scopedKey(_ suffix: String) -> String {
        "\(Self.keyPrefix).\(activeStorageScope).\(suffix)"
    }

    static func userScopedDefaultsKey(_ base: String) -> String {
        "\(base).\(storageScopeUserID())"
    }

    // MARK: - Date Helpers

    private static func dateString(for date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private static func yesterday() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    }

    private static func storageScopeUserID() -> String {
        let rawUserID = Auth.auth().currentUser?.uid.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return rawUserID.isEmpty ? guestUserID : rawUserID
    }

    private func syncStreakSnapshot() {
        let request = StreakSnapshotUpsertRequest(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastQualifiedDate: lastQualifiedDate
        )

        Task {
            do {
                _ = try await syncService.syncStreakSnapshot(request)
            } catch {
#if DEBUG
                print("syncStreakSnapshot failed: \(error.localizedDescription)")
#endif
            }
        }
    }

    private static func intValue(_ value: JSONValue?) -> Int? {
        guard let value else { return nil }
        switch value {
        case .int(let intValue):
            return intValue
        case .double(let doubleValue):
            return Int(doubleValue)
        case .string(let stringValue):
            return Int(stringValue)
        default:
            return nil
        }
    }

    private static func stringValue(_ value: JSONValue?) -> String? {
        guard let value else { return nil }
        switch value {
        case .string(let stringValue):
            return stringValue
        default:
            return nil
        }
    }
}
