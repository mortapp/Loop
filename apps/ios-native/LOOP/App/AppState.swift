import Foundation
import Observation
import SwiftUI

/// Global state only: session, active account and user preferences.
/// Feature state lives in the feature's own view model.
@MainActor
@Observable
final class AppState {
    private(set) var authentication: AuthenticationState = .checkingSession
    var preferences: LoopPreferences

    private let environment: AppEnvironment
    private var session: LoopSession?

    init(environment: AppEnvironment) {
        self.environment = environment
        self.preferences = LoopPreferences.load()
        LoopHaptics.isEnabled = preferences.hapticsEnabled
    }

    var profile: LoopProfile? {
        switch authentication {
        case .signedIn(let profile), .onboarding(let profile): return profile
        default: return nil
        }
    }

    var activeAccountID: UUID? { profile?.activeAccountID }

    var isSignedIn: Bool {
        if case .signedIn = authentication { return true }
        return false
    }

    /// True when LOOP is running on clearly-labelled sample data.
    var isSampleMode: Bool { environment.mode.isSample }

    // MARK: - Lifecycle

    func bootstrap() async {
        authentication = .checkingSession
        do {
            guard let restored = try await environment.authService.restoreSession() else {
                authentication = .signedOut
                return
            }
            session = restored
            await loadProfile(for: restored)
        } catch {
            authentication = .failed(LoopError.map(error))
        }
    }

    func signInWithGoogle() async {
        authentication = .authenticating
        do {
            let newSession = try await environment.authService.signInWithGoogle()
            session = newSession
            await loadProfile(for: newSession)
            LoopHaptics.success()
        } catch let error as LoopError where error == .cancelled {
            authentication = .signedOut
        } catch {
            LoopLog.failure(LoopLog.auth, "sign-in", error)
            authentication = .failed(LoopError.map(error))
        }
    }

    func handleAuthCallback(url: URL) async {
        authentication = .authenticating
        do {
            let newSession = try await environment.authService.handleCallback(url: url)
            session = newSession
            await loadProfile(for: newSession)
        } catch {
            authentication = .failed(LoopError.map(error))
        }
    }

    func signOut() async {
        try? await environment.authService.signOut()
        session = nil
        authentication = .signedOut
        LoopHaptics.impact(.medium)
    }

    func retry() async {
        await bootstrap()
    }

    private func loadProfile(for session: LoopSession) async {
        authentication = .bootstrappingAccount
        do {
            let profile = try await environment.accountService.loadProfile(session: session)
            authentication = profile.hasCompletedOnboarding ? .signedIn(profile) : .onboarding(profile)
        } catch {
            LoopLog.failure(LoopLog.auth, "profile bootstrap", error)
            authentication = .failed(LoopError.map(error))
        }
    }

    // MARK: - Account

    func completeOnboarding(displayName: String, username: String, password: String, accountName: String) async {
        guard case .onboarding(let profile) = authentication else { return }
        do {
            let updated = try await environment.accountService.completeOnboarding(
                profile: profile,
                displayName: displayName,
                username: username,
                password: password,
                accountName: accountName
            )
            authentication = .signedIn(updated)
            LoopHaptics.success()
        } catch {
            authentication = .failed(LoopError.map(error))
        }
    }

    func switchAccount(to accountID: UUID) async {
        guard let profile else { return }
        do {
            let updated = try await environment.accountService.switchAccount(profile: profile, to: accountID)
            authentication = .signedIn(updated)
            LoopHaptics.selection()
        } catch {
            LoopLog.failure(LoopLog.app, "account switch", error)
        }
    }

    // MARK: - Preferences

    func update(_ mutate: (inout LoopPreferences) -> Void) {
        var copy = preferences
        mutate(&copy)
        preferences = copy
        LoopHaptics.isEnabled = copy.hapticsEnabled
        copy.save()
    }
}

/// Local, non-sensitive user preferences.
nonisolated struct LoopPreferences: Codable, Hashable, Sendable {
    var appearance: Appearance
    var hapticsEnabled: Bool
    var actionDensity: ActionDensity
    var showsCentsInSummaries: Bool
    var defaultMoneyFilter: MoneyFilter

    nonisolated enum Appearance: String, Codable, CaseIterable, Identifiable, Sendable {
        case system, light, dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    nonisolated enum ActionDensity: String, Codable, CaseIterable, Identifiable, Sendable {
        case focused, balanced, everything

        var id: String { rawValue }

        var label: String {
            switch self {
            case .focused: return "Focused"
            case .balanced: return "Balanced"
            case .everything: return "Everything"
            }
        }

        var detail: String {
            switch self {
            case .focused: return "Only urgent and time-critical actions."
            case .balanced: return "Urgent, soon and money-making opportunities."
            case .everything: return "Every action LOOP generates, including updates."
            }
        }

        /// Priorities included in Today at this density.
        var includedPriorities: Set<ActionPriority> {
            switch self {
            case .focused: return [.urgent, .high]
            case .balanced: return [.urgent, .high, .normal]
            case .everything: return Set(ActionPriority.allCases)
            }
        }
    }

    static let `default` = LoopPreferences(
        appearance: .system,
        hapticsEnabled: true,
        actionDensity: .balanced,
        showsCentsInSummaries: false,
        defaultMoneyFilter: .all
    )

    private static let storageKey = "loop.preferences.v1"

    static func load() -> LoopPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(LoopPreferences.self, from: data) else {
            return .default
        }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
