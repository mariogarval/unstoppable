import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

enum APIAuthMode: Sendable {
    case none
    case devUserID(String)
    case bearerTokenProvider(@Sendable () async throws -> String)
}

enum APIClientError: LocalizedError {
    case invalidBaseURL
    case missingAuthToken
    case unexpectedResponse
    case requestFailed(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "API base URL is invalid."
        case .missingAuthToken:
            return "Missing auth token for authorized request."
        case .unexpectedResponse:
            return "Unexpected response from API."
        case .requestFailed(let statusCode, let body):
            return "API request failed with status \(statusCode): \(body)"
        }
    }
}

struct APIEnvironment {
    private static let fallbackBaseURLString = "https://unstoppable-api-1094359674860.us-central1.run.app"

    static var baseURL: URL {
        let configured = infoString(forKey: "API_BASE_URL")
        if let configured, let url = URL(string: configured), !configured.isEmpty {
            return url
        }
        return URL(string: fallbackBaseURLString)!
    }

    static var defaultAuthMode: APIAuthMode {
        #if DEBUG
        let defaultUseDevAuth = true
        let defaultDevUserID = "dev-user-001"
        #else
        let defaultUseDevAuth = false
        let defaultDevUserID = ""
        #endif

        if infoBool(forKey: "API_USE_DEV_AUTH", defaultValue: defaultUseDevAuth) {
            let configuredID = infoString(forKey: "API_DEV_USER_ID")?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let configuredID, !configuredID.isEmpty {
                return .devUserID(configuredID)
            }
            return .devUserID(defaultDevUserID)
        }
        return .none
    }

    private static func infoString(forKey key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
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

struct EmptyResponse: Decodable {}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let baseURL: URL
    private var authMode: APIAuthMode

    init(
        session: URLSession = .shared,
        baseURL: URL = APIEnvironment.baseURL,
        authMode: APIAuthMode = APIEnvironment.defaultAuthMode
    ) {
        self.session = session
        self.baseURL = baseURL
        self.authMode = authMode

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func setAuthMode(_ mode: APIAuthMode) {
        authMode = mode
    }

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        try await send(method: .get, path: path, body: Optional<Int>.none, as: type)
    }

    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body, as type: T.Type = T.self) async throws -> T {
        try await send(method: .post, path: path, body: body, as: type)
    }

    func put<Body: Encodable, T: Decodable>(_ path: String, body: Body, as type: T.Type = T.self) async throws -> T {
        try await send(method: .put, path: path, body: body, as: type)
    }

    private func send<Body: Encodable, T: Decodable>(
        method: HTTPMethod,
        path: String,
        body: Body?,
        as responseType: T.Type
    ) async throws -> T {
        let request = try await buildRequest(method: method, path: path, body: body)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.unexpectedResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "<non-utf8-body>"
            throw APIClientError.requestFailed(statusCode: httpResponse.statusCode, body: responseBody)
        }

        if responseType == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! T
        }

        return try decoder.decode(T.self, from: data)
    }

    private func buildRequest<Body: Encodable>(
        method: HTTPMethod,
        path: String,
        body: Body?
    ) async throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIClientError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        switch authMode {
        case .none:
            break
        case .devUserID(let userID):
            request.setValue(userID, forHTTPHeaderField: "X-User-Id")
        case .bearerTokenProvider(let tokenProvider):
            let token = try await tokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { throw APIClientError.missingAuthToken }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }
}
