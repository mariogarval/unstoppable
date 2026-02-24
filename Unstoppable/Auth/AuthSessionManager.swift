import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import Security
import UIKit

enum AuthSessionError: LocalizedError {
    case missingClientID
    case missingPresentingViewController
    case missingGoogleIDToken
    case missingFirebaseUser
    case missingFirebaseIDToken
    case invalidAppleCredential
    case missingAppleIdentityToken
    case invalidAppleIdentityToken
    case missingAppleNonce
    case appleEmailUnavailableForLinking
    case appleCredentialRequiresGoogleSignIn
    case appleCredentialRequiresExistingProvider(methods: [String])

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Missing Firebase client configuration."
        case .missingPresentingViewController:
            return "Unable to present Google sign-in."
        case .missingGoogleIDToken:
            return "Google sign-in did not provide an ID token."
        case .missingFirebaseUser:
            return "No authenticated Firebase user is available."
        case .missingFirebaseIDToken:
            return "Unable to fetch Firebase ID token."
        case .invalidAppleCredential:
            return "Unable to read Apple sign-in credential."
        case .missingAppleIdentityToken:
            return "Apple sign-in did not provide an identity token."
        case .invalidAppleIdentityToken:
            return "Apple sign-in identity token is invalid."
        case .missingAppleNonce:
            return "Apple sign-in request expired. Please try again."
        case .appleEmailUnavailableForLinking:
            return "Apple did not provide an email for linking. Sign in with Google and link Apple from there."
        case .appleCredentialRequiresGoogleSignIn:
            return "This email is already linked to Google. Sign in with Google to finish linking Apple."
        case .appleCredentialRequiresExistingProvider(let methods):
            if methods.isEmpty {
                return "An account with this email already exists with another sign-in method."
            }
            return "An account with this email already exists. Use: \(methods.joined(separator: ", "))."
        }
    }
}

@MainActor
final class AuthSessionManager {
    static let shared = AuthSessionManager()

    private let syncService: UserDataSyncService

    private var currentAppleNonce: String?
    private var pendingAppleCredentialToLink: AuthCredential?
    private var pendingAppleLinkEmail: String?

    init(syncService: UserDataSyncService = .shared) {
        self.syncService = syncService
    }

    @discardableResult
    func restoreSessionIfPossible() async -> Bool {
        guard let currentUser = Auth.auth().currentUser else { return false }
        await RevenueCatManager.shared.logIn(appUserID: currentUser.uid, email: currentUser.email)
        await syncService.setAuthMode(makeBearerMode())
        return true
    }

    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func signInWithApple(result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthSessionError.invalidAppleCredential
            }
            try await signInWithAppleCredential(credential)
        case .failure(let error):
            throw error
        }
    }

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthSessionError.missingClientID
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let presentingVC = try presentingViewController()
        let signInResult = try await googleSignInResult(with: presentingVC)

        guard let idToken = signInResult.user.idToken?.tokenString else {
            throw AuthSessionError.missingGoogleIDToken
        }

        let accessToken = signInResult.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await firebaseSignIn(with: credential)
        try await linkPendingAppleCredentialIfNeeded(to: authResult.user)
        await applyAuthenticatedSession(for: authResult.user)
    }

    func signOut() async throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
        clearPendingAppleLinkState()
        currentAppleNonce = nil
        await RevenueCatManager.shared.logOut()
        await syncService.setAuthMode(APIEnvironment.defaultAuthMode)
    }

    private func signInWithAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async throws {
        guard let rawNonce = currentAppleNonce else {
            throw AuthSessionError.missingAppleNonce
        }
        currentAppleNonce = nil

        guard let tokenData = credential.identityToken else {
            throw AuthSessionError.missingAppleIdentityToken
        }
        guard let tokenString = String(data: tokenData, encoding: .utf8), !tokenString.isEmpty else {
            throw AuthSessionError.invalidAppleIdentityToken
        }

        let firebaseAppleCredential = OAuthProvider.credential(
            providerID: .apple,
            idToken: tokenString,
            rawNonce: rawNonce
        )

        do {
            let authResult = try await firebaseSignIn(with: firebaseAppleCredential)
            await applyAuthenticatedSession(for: authResult.user)
        } catch let error as NSError {
            guard AuthErrorCode(rawValue: error.code) == .accountExistsWithDifferentCredential else {
                throw error
            }
            try await prepareAppleCredentialLinking(
                error: error,
                appleCredential: credential,
                firebaseAppleCredential: firebaseAppleCredential
            )
        }
    }

    private func prepareAppleCredentialLinking(
        error: NSError,
        appleCredential: ASAuthorizationAppleIDCredential,
        firebaseAppleCredential: AuthCredential
    ) async throws {
        let email = try resolveAppleEmail(for: appleCredential, error: error)
        let methods = try await fetchSignInMethods(forEmail: email)

        if methods.contains("google.com") {
            pendingAppleCredentialToLink = firebaseAppleCredential
            pendingAppleLinkEmail = email
            throw AuthSessionError.appleCredentialRequiresGoogleSignIn
        }

        throw AuthSessionError.appleCredentialRequiresExistingProvider(methods: methods)
    }

    private func resolveAppleEmail(
        for credential: ASAuthorizationAppleIDCredential,
        error: NSError
    ) throws -> String {
        if let email = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email.lowercased()
        }

        if let email = error.userInfo[AuthErrorUserInfoEmailKey] as? String {
            let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !normalized.isEmpty {
                return normalized
            }
        }

        if let email = pendingAppleLinkEmail, !email.isEmpty {
            return email
        }

        throw AuthSessionError.appleEmailUnavailableForLinking
    }

    private func linkPendingAppleCredentialIfNeeded(to user: User) async throws {
        guard let credential = pendingAppleCredentialToLink else { return }

        do {
            _ = try await link(user: user, with: credential)
            clearPendingAppleLinkState()
        } catch let error as NSError {
            let authCode = AuthErrorCode(rawValue: error.code)
            if authCode == .providerAlreadyLinked || authCode == .credentialAlreadyInUse {
                clearPendingAppleLinkState()
                return
            }
            throw error
        }
    }

    private func clearPendingAppleLinkState() {
        pendingAppleCredentialToLink = nil
        pendingAppleLinkEmail = nil
    }

    private func applyAuthenticatedSession(for user: User) async {
        await RevenueCatManager.shared.logIn(appUserID: user.uid, email: user.email)
        await syncService.setAuthMode(makeBearerMode())
    }

    /// `fetchSignInMethods` is deprecated and unreliable when Email Enumeration Protection is enabled.
    /// It may return an empty list even for existing accounts.
    /// Handle this ambiguity carefully in your logic.
    @available(*, deprecated, message: "fetchSignInMethods is unreliable with Email Enumeration Protection enabled and may return empty list even for existing accounts.")
    private func fetchSignInMethods(forEmail email: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().fetchSignInMethods(forEmail: email) { methods, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                // If methods is empty, this could mean either no providers or enumeration protection is enabled
                continuation.resume(returning: methods ?? [])
            }
        }
    }

    private func link(user: User, with credential: AuthCredential) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            user.link(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else {
                    continuation.resume(throwing: AuthSessionError.missingFirebaseUser)
                    return
                }

                continuation.resume(returning: result)
            }
        }
    }

    private func makeBearerMode() -> APIAuthMode {
        .bearerTokenProvider {
            try await Self.currentFirebaseIDToken()
        }
    }

    private static func currentFirebaseIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthSessionError.missingFirebaseUser
        }

        return try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenForcingRefresh(false) { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let token, !token.isEmpty else {
                    continuation.resume(throwing: AuthSessionError.missingFirebaseIDToken)
                    return
                }

                continuation.resume(returning: token)
            }
        }
    }

    private func googleSignInResult(with presentingVC: UIViewController) async throws -> GIDSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else {
                    continuation.resume(throwing: AuthSessionError.missingGoogleIDToken)
                    return
                }

                continuation.resume(returning: result)
            }
        }
    }

    private func firebaseSignIn(with credential: AuthCredential) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else {
                    continuation.resume(throwing: AuthSessionError.missingFirebaseUser)
                    return
                }

                continuation.resume(returning: result)
            }
        }
    }

    private func presentingViewController() throws -> UIViewController {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
            let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            throw AuthSessionError.missingPresentingViewController
        }

        return topMostViewController(from: rootVC)
    }

    private func topMostViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let nav = root as? UINavigationController, let visible = nav.visibleViewController {
            return topMostViewController(from: visible)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }
        return root
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

            if status != errSecSuccess {
                let fallback = UUID().uuidString.replacingOccurrences(of: "-", with: "")
                result.append(contentsOf: fallback.prefix(remainingLength))
                break
            }

            randomBytes.forEach { byte in
                guard remainingLength > 0 else { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

