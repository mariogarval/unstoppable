import Foundation
import FirebaseAuth

final class UserDataSyncService {
    static let shared = UserDataSyncService()

    private let apiClient: APIClient
    private let guestStore = GuestSyncStore()

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func setAuthMode(_ mode: APIAuthMode) async {
        await apiClient.setAuthMode(mode)
    }

    func enterGuestMode() async {
        await apiClient.setAuthMode(.none)
    }

    func flushPendingGuestDataIfNeeded() async {
        guard hasAuthenticatedFirebaseUser else { return }

        var state = await guestStore.loadState()

        if let profile = state.profile {
            do {
                _ = try await syncUserProfileRemote(profile)
                state.profile = nil
            } catch {
#if DEBUG
                print("flushPendingGuestData(profile) failed: \(error.localizedDescription)")
#endif
            }
        }

        if let routine = state.routine {
            do {
                _ = try await syncCurrentRoutineRemote(routine)
                state.routine = nil
            } catch {
#if DEBUG
                print("flushPendingGuestData(routine) failed: \(error.localizedDescription)")
#endif
            }
        }

        if !state.dailyProgressByDate.isEmpty {
            for date in state.dailyProgressByDate.keys.sorted() {
                guard let request = state.dailyProgressByDate[date] else { continue }
                do {
                    _ = try await syncDailyProgressRemote(request)
                    state.dailyProgressByDate.removeValue(forKey: date)
                } catch {
#if DEBUG
                    print("flushPendingGuestData(progress \(date)) failed: \(error.localizedDescription)")
#endif
                }
            }
        }

        if let streak = state.streak {
            do {
                _ = try await syncStreakSnapshotRemote(streak)
                state.streak = nil
            } catch {
#if DEBUG
                print("flushPendingGuestData(streak) failed: \(error.localizedDescription)")
#endif
            }
        }

        if let subscription = state.subscription {
            do {
                _ = try await syncSubscriptionSnapshotRemote(subscription)
                state.subscription = nil
            } catch {
#if DEBUG
                print("flushPendingGuestData(subscription) failed: \(error.localizedDescription)")
#endif
            }
        }

        await guestStore.saveState(state)
    }

    @discardableResult
    func syncUserProfile(_ request: UserProfileUpsertRequest) async throws -> APIAckResponse {
        guard hasAuthenticatedFirebaseUser else {
            await guestStore.upsertProfile(request)
            return APIAckResponse(ok: true, userId: nil, date: nil)
        }

        return try await syncUserProfileRemote(request)
    }

    @discardableResult
    func syncCurrentRoutine(_ request: RoutineUpsertRequest) async throws -> APIAckResponse {
        guard hasAuthenticatedFirebaseUser else {
            await guestStore.upsertRoutine(request)
            return APIAckResponse(ok: true, userId: nil, date: nil)
        }

        return try await syncCurrentRoutineRemote(request)
    }

    @discardableResult
    func syncDailyProgress(_ request: DailyProgressUpsertRequest) async throws -> APIAckResponse {
        guard hasAuthenticatedFirebaseUser else {
            await guestStore.upsertDailyProgress(request)
            return APIAckResponse(ok: true, userId: nil, date: nil)
        }

        return try await syncDailyProgressRemote(request)
    }

    @discardableResult
    func syncStreakSnapshot(_ request: StreakSnapshotUpsertRequest) async throws -> APIAckResponse {
        guard hasAuthenticatedFirebaseUser else {
            await guestStore.upsertStreak(request)
            return APIAckResponse(ok: true, userId: nil, date: nil)
        }

        return try await syncStreakSnapshotRemote(request)
    }

    @discardableResult
    func syncSubscriptionSnapshot(_ request: SubscriptionSnapshotUpsertRequest) async throws -> APIAckResponse {
        guard hasAuthenticatedFirebaseUser else {
            await guestStore.upsertSubscription(request)
            return APIAckResponse(ok: true, userId: nil, date: nil)
        }

        return try await syncSubscriptionSnapshotRemote(request)
    }

    func fetchBootstrap() async throws -> BootstrapResponse {
        guard hasAuthenticatedFirebaseUser else {
            return await guestStore.makeGuestBootstrap()
        }
        return try await apiClient.get("/v1/bootstrap", as: BootstrapResponse.self)
    }

    func makeDailyProgressRequest(
        date: Date = Date(),
        completed: Int,
        total: Int,
        completedTaskIds: [String]
    ) -> DailyProgressUpsertRequest {
        DailyProgressUpsertRequest(
            date: Self.dayFormatter.string(from: date),
            completed: completed,
            total: total,
            completedTaskIds: completedTaskIds
        )
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var hasAuthenticatedFirebaseUser: Bool {
        Auth.auth().currentUser != nil
    }

    private func syncUserProfileRemote(_ request: UserProfileUpsertRequest) async throws -> APIAckResponse {
        try await apiClient.post("/v1/user/profile", body: request, as: APIAckResponse.self)
    }

    private func syncCurrentRoutineRemote(_ request: RoutineUpsertRequest) async throws -> APIAckResponse {
        try await apiClient.put("/v1/routines/current", body: request, as: APIAckResponse.self)
    }

    private func syncDailyProgressRemote(_ request: DailyProgressUpsertRequest) async throws -> APIAckResponse {
        try await apiClient.post("/v1/progress/daily", body: request, as: APIAckResponse.self)
    }

    private func syncStreakSnapshotRemote(_ request: StreakSnapshotUpsertRequest) async throws -> APIAckResponse {
        try await apiClient.post("/v1/stats/streak/snapshot", body: request, as: APIAckResponse.self)
    }

    private func syncSubscriptionSnapshotRemote(_ request: SubscriptionSnapshotUpsertRequest) async throws -> APIAckResponse {
        try await apiClient.post("/v1/payments/subscription/snapshot", body: request, as: APIAckResponse.self)
    }
}

private struct GuestDraftState: Codable {
    var profile: UserProfileUpsertRequest?
    var routine: RoutineUpsertRequest?
    var dailyProgressByDate: [String: DailyProgressUpsertRequest]
    var streak: StreakSnapshotUpsertRequest?
    var subscription: SubscriptionSnapshotUpsertRequest?

    static let empty = GuestDraftState(
        profile: nil,
        routine: nil,
        dailyProgressByDate: [:],
        streak: nil,
        subscription: nil
    )
}

private actor GuestSyncStore {
    private let defaults = UserDefaults.standard
    private let key = "guest.sync.draft.state.v1"

    func loadState() -> GuestDraftState {
        guard
            let data = defaults.data(forKey: key),
            let state = try? JSONDecoder().decode(GuestDraftState.self, from: data)
        else {
            return .empty
        }
        return state
    }

    func saveState(_ state: GuestDraftState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    func upsertProfile(_ request: UserProfileUpsertRequest) {
        var state = loadState()
        state.profile = mergeProfile(existing: state.profile, incoming: request)
        saveState(state)
    }

    func upsertRoutine(_ request: RoutineUpsertRequest) {
        var state = loadState()
        state.routine = request
        saveState(state)
    }

    func upsertDailyProgress(_ request: DailyProgressUpsertRequest) {
        var state = loadState()
        state.dailyProgressByDate[request.date] = request
        saveState(state)
    }

    func upsertStreak(_ request: StreakSnapshotUpsertRequest) {
        var state = loadState()
        state.streak = request
        saveState(state)
    }

    func upsertSubscription(_ request: SubscriptionSnapshotUpsertRequest) {
        var state = loadState()
        state.subscription = request
        saveState(state)
    }

    func makeGuestBootstrap() -> BootstrapResponse {
        let state = loadState()
        let profile = makeProfile(from: state.profile)
        let routine = makeRoutine(from: state.routine)
        let streak = makeStreak(from: state.streak)
        let progress = makeProgress(from: state.dailyProgressByDate)
        let subscription = makeSubscription(from: state.subscription)

        return BootstrapResponse(
            userId: "guest-local",
            profile: profile,
            isProfileComplete: nil,
            profileCompletion: nil,
            routine: routine,
            streak: streak,
            progress: BootstrapProgress(today: progress),
            subscription: subscription.isEmpty ? nil : subscription
        )
    }

    private func mergeProfile(existing: UserProfileUpsertRequest?, incoming: UserProfileUpsertRequest) -> UserProfileUpsertRequest {
        UserProfileUpsertRequest(
            nickname: incoming.nickname ?? existing?.nickname,
            ageGroup: incoming.ageGroup ?? existing?.ageGroup,
            gender: incoming.gender ?? existing?.gender,
            idealDailyLifeSelections: incoming.idealDailyLifeSelections ?? existing?.idealDailyLifeSelections,
            notificationsEnabled: incoming.notificationsEnabled ?? existing?.notificationsEnabled,
            termsAccepted: incoming.termsAccepted ?? existing?.termsAccepted,
            termsOver16Accepted: incoming.termsOver16Accepted ?? existing?.termsOver16Accepted,
            termsMarketingAccepted: incoming.termsMarketingAccepted ?? existing?.termsMarketingAccepted,
            paymentOption: incoming.paymentOption ?? existing?.paymentOption
        )
    }

    private func makeProfile(from request: UserProfileUpsertRequest?) -> [String: JSONValue] {
        guard let request else { return [:] }

        var profile: [String: JSONValue] = [:]
        if let nickname = request.nickname {
            profile["nickname"] = .string(nickname)
        }
        if let ageGroup = request.ageGroup {
            profile["ageGroup"] = .string(ageGroup)
        }
        if let gender = request.gender {
            profile["gender"] = .string(gender)
        }
        if let idealDailyLifeSelections = request.idealDailyLifeSelections {
            profile["idealDailyLifeSelections"] = .array(idealDailyLifeSelections.map { .string($0) })
        }
        if let notificationsEnabled = request.notificationsEnabled {
            profile["notificationsEnabled"] = .bool(notificationsEnabled)
        }
        if let termsAccepted = request.termsAccepted {
            profile["termsAccepted"] = .bool(termsAccepted)
        }
        if let termsOver16Accepted = request.termsOver16Accepted {
            profile["termsOver16Accepted"] = .bool(termsOver16Accepted)
        }
        if let termsMarketingAccepted = request.termsMarketingAccepted {
            profile["termsMarketingAccepted"] = .bool(termsMarketingAccepted)
        }
        if let paymentOption = request.paymentOption {
            profile["paymentOption"] = .string(paymentOption)
        }
        return profile
    }

    private func makeRoutine(from request: RoutineUpsertRequest?) -> [String: JSONValue] {
        guard let request else { return [:] }

        var routine: [String: JSONValue] = [:]
        if let routineTime = request.routineTime {
            routine["routineTime"] = .string(routineTime)
        }
        routine["tasks"] = .array(request.tasks.map { task in
            .object([
                "id": .string(task.id),
                "title": .string(task.title),
                "icon": .string(task.icon),
                "duration": .int(task.duration),
                "isCompleted": .bool(task.isCompleted)
            ])
        })
        return routine
    }

    private func makeStreak(from request: StreakSnapshotUpsertRequest?) -> [String: JSONValue] {
        guard let request else { return [:] }
        return [
            "currentStreak": .int(request.currentStreak),
            "longestStreak": .int(request.longestStreak),
            "lastQualifiedDate": .string(request.lastQualifiedDate)
        ]
    }

    private func makeProgress(from progressByDate: [String: DailyProgressUpsertRequest]) -> [String: JSONValue] {
        let today = UserDataSyncService.makeTodayDateString()
        let progress = progressByDate[today]
        return [
            "date": .string(today),
            "completed": .int(progress?.completed ?? 0),
            "total": .int(progress?.total ?? 0),
            "completedTaskIds": .array((progress?.completedTaskIds ?? []).map { .string($0) })
        ]
    }

    private func makeSubscription(from request: SubscriptionSnapshotUpsertRequest?) -> [String: JSONValue] {
        guard let request else { return [:] }

        var subscription: [String: JSONValue] = [:]
        if let entitlementId = request.entitlementId {
            subscription["entitlementId"] = .string(entitlementId)
        }
        if !request.entitlementIds.isEmpty {
            subscription["entitlementIds"] = .array(request.entitlementIds.map { .string($0) })
        }
        subscription["isActive"] = .bool(request.isActive)
        if let productId = request.productId {
            subscription["productId"] = .string(productId)
        }
        if let paymentOption = request.paymentOption {
            subscription["paymentOption"] = .string(paymentOption)
        }
        if let store = request.store {
            subscription["store"] = .string(store)
        }
        if let periodType = request.periodType {
            subscription["periodType"] = .string(periodType)
        }
        if let expirationAt = request.expirationAt {
            subscription["expirationAt"] = .string(expirationAt.ISO8601Format())
        }
        if let gracePeriodExpiresAt = request.gracePeriodExpiresAt {
            subscription["gracePeriodExpiresAt"] = .string(gracePeriodExpiresAt.ISO8601Format())
        }
        return subscription
    }
}

private extension UserDataSyncService {
    static func makeTodayDateString() -> String {
        dayFormatter.string(from: Date())
    }
}
