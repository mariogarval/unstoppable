import Foundation

final class UserDataSyncService {
    static let shared = UserDataSyncService()

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func setAuthMode(_ mode: APIAuthMode) async {
        await apiClient.setAuthMode(mode)
    }

    @discardableResult
    func syncUserProfile(_ request: UserProfileUpsertRequest) async throws -> APIAckResponse {
        try await apiClient.post("/v1/user/profile", body: request, as: APIAckResponse.self)
    }

    @discardableResult
    func syncCurrentRoutine(_ request: RoutineUpsertRequest) async throws -> APIAckResponse {
        try await apiClient.put("/v1/routines/current", body: request, as: APIAckResponse.self)
    }

    @discardableResult
    func syncDailyProgress(_ request: DailyProgressUpsertRequest) async throws -> APIAckResponse {
        try await apiClient.post("/v1/progress/daily", body: request, as: APIAckResponse.self)
    }

    @discardableResult
    func syncStreakSnapshot(_ request: StreakSnapshotUpsertRequest) async throws -> APIAckResponse {
        try await apiClient.post("/v1/stats/streak/snapshot", body: request, as: APIAckResponse.self)
    }

    func fetchBootstrap() async throws -> BootstrapResponse {
        try await apiClient.get("/v1/bootstrap", as: BootstrapResponse.self)
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
}
