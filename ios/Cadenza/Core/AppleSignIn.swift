import AuthenticationServices
import CryptoKit
import UIKit

// MARK: - Nonce helpers

enum NonceError: Error { case secRandomFailed }

func makeRandomNonce(length: Int = 32) throws -> String {
    var bytes = [UInt8](repeating: 0, count: length)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
        throw NonceError.secRandomFailed
    }
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    return String(bytes.map { charset[Int($0) % charset.count] })
}

func sha256Hex(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8))
        .map { String(format: "%02x", $0) }
        .joined()
}

// MARK: - Coordinator

/// Bridges ASAuthorizationControllerDelegate → async/await.
/// Must be retained for the lifetime of the authorization request.
@MainActor
final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?.keyWindow
            ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: ASAuthorizationError(.unknown))
            continuation = nil
            return
        }
        continuation?.resume(returning: cred)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func requestCredential() async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { self.continuation = $0 }
    }
}
