import Foundation

struct APIAckResponse: Codable, Sendable {
    let ok: Bool
    let userId: String?
    let date: String?
}

struct UserProfileUpsertRequest: Codable, Sendable {
    let nickname: String?
    let ageGroup: String?
    let gender: String?
    let notificationsEnabled: Bool?
    let termsAccepted: Bool?
    let termsOver16Accepted: Bool?
    let termsMarketingAccepted: Bool?
    let paymentOption: String?

    init(
        nickname: String? = nil,
        ageGroup: String? = nil,
        gender: String? = nil,
        notificationsEnabled: Bool? = nil,
        termsAccepted: Bool? = nil,
        termsOver16Accepted: Bool? = nil,
        termsMarketingAccepted: Bool? = nil,
        paymentOption: String? = nil
    ) {
        self.nickname = nickname
        self.ageGroup = ageGroup
        self.gender = gender
        self.notificationsEnabled = notificationsEnabled
        self.termsAccepted = termsAccepted
        self.termsOver16Accepted = termsOver16Accepted
        self.termsMarketingAccepted = termsMarketingAccepted
        self.paymentOption = paymentOption
    }
}

struct RoutineTaskPayload: Codable, Sendable {
    let id: String
    let title: String
    let icon: String
    let duration: Int
    let isCompleted: Bool
}

struct RoutineUpsertRequest: Codable, Sendable {
    let routineTime: String?
    let tasks: [RoutineTaskPayload]
}

struct DailyProgressUpsertRequest: Codable, Sendable {
    let date: String
    let completed: Int
    let total: Int
    let completedTaskIds: [String]
}

struct StreakSnapshotUpsertRequest: Codable, Sendable {
    let currentStreak: Int
    let longestStreak: Int
    let lastQualifiedDate: String
}

struct SubscriptionSnapshotUpsertRequest: Codable, Sendable {
    let entitlementId: String?
    let entitlementIds: [String]
    let isActive: Bool
    let productId: String?
    let paymentOption: String?
    let store: String?
    let periodType: String?
    let expirationAt: Date?
    let gracePeriodExpiresAt: Date?
}

struct BootstrapResponse: Codable, Sendable {
    let userId: String
    let profile: [String: JSONValue]
    let isProfileComplete: Bool?
    let profileCompletion: BootstrapProfileCompletion?
    let routine: [String: JSONValue]
    let streak: [String: JSONValue]
    let progress: BootstrapProgress
    let subscription: [String: JSONValue]?
}

struct BootstrapProfileCompletion: Codable, Sendable {
    let isComplete: Bool
    let missingRequiredFields: [String]
}

struct BootstrapProgress: Codable, Sendable {
    let today: [String: JSONValue]
}

enum JSONValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
