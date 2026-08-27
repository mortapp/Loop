import Foundation

/// The authenticated person.
nonisolated struct LoopUser: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var email: String
    var username: String? = nil
    var avatarURL: URL?
    var createdAt: Date

    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "L" : letters.joined().uppercased()
    }
}

/// A LOOP account. Every record in LOOP belongs to exactly one account.
nonisolated struct LoopAccount: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var kind: Kind
    var currencyCode: String
    var createdAt: Date

    nonisolated enum Kind: String, Codable, Hashable, Sendable, CaseIterable {
        case personal
        case business

        var label: String {
            switch self {
            case .personal: return "Personal"
            case .business: return "Business"
            }
        }

        var symbolName: String {
            switch self {
            case .personal: return "person"
            case .business: return "building.2"
            }
        }
    }
}

/// A user's LOOP profile state — determines whether onboarding is required.
nonisolated struct LoopProfile: Codable, Hashable, Sendable {
    var user: LoopUser
    var accounts: [LoopAccount]
    var activeAccountID: UUID
    var hasCompletedOnboarding: Bool

    var activeAccount: LoopAccount {
        accounts.first(where: { $0.id == activeAccountID }) ?? accounts[0]
    }
}

/// Authenticated session material. Tokens are never logged or rendered.
nonisolated struct LoopSession: Codable, Hashable, Sendable {
    let userID: UUID
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    var isExpired: Bool { expiresAt <= Date() }
}

nonisolated enum AuthenticationState: Equatable, Sendable {
    case checkingSession
    case signedOut
    case authenticating
    case bootstrappingAccount
    case onboarding(LoopProfile)
    case signedIn(LoopProfile)
    case failed(LoopError)
}
