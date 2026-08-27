import AuthenticationServices
import UIKit

/// Runs the browser leg of Supabase OAuth/PKCE using the system web session,
/// so credentials are entered in Safari and never inside LOOP.
@MainActor
final class OAuthWebSession: NSObject {
    private var session: ASWebAuthenticationSession?

    func start(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    let code = (error as NSError).code
                    if code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: LoopError.cancelled)
                    } else {
                        continuation.resume(throwing: LoopError.unauthorized)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: LoopError.unauthorized)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                continuation.resume(throwing: LoopError.serviceUnavailable(
                    "LOOP couldn't open the secure sign-in browser."
                ))
            }
        }
    }
}

extension OAuthWebSession: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return scene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}
