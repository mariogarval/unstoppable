import Foundation
import UIKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

enum AuthSessionError: LocalizedError {
    case missingClientID
    case missingPresentingViewController
    case missingGoogleIDToken
    case missingFirebaseUser
    case missingFirebaseIDToken

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
        }
    }
}

@MainActor
final class AuthSessionManager {
    static let shared = AuthSessionManager()

    private let syncService: UserDataSyncService

    init(syncService: UserDataSyncService = .shared) {
        self.syncService = syncService
    }

    @discardableResult
    func restoreSessionIfPossible() async -> Bool {
        guard Auth.auth().currentUser != nil else { return false }
        await syncService.setAuthMode(makeBearerMode())
        return true
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
        _ = try await firebaseSignIn(with: credential)
        await syncService.setAuthMode(makeBearerMode())
    }

    func signOut() async throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
        await syncService.setAuthMode(APIEnvironment.defaultAuthMode)
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
}
