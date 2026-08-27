import Foundation

/// A resolved LOOP deep link.
nonisolated enum LoopDeepLink: Hashable, Sendable {
    case tab(LoopTab)
    case destination(AppDestination, tab: LoopTab)
    case search
}

/// Central URL parsing. No screen parses URLs on its own.
///
/// Supported:
/// `loop://today`, `loop://money`, `loop://sell`, `loop://business`, `loop://ask`
/// `loop://purchase/{id}`, `loop://return/{id}`, `loop://refund/{id}`,
/// `loop://warranty/{id}`, `loop://item/{id}`, `loop://sale/{id}`,
/// `loop://lead/{id}`, `loop://opportunity/{id}`, `loop://quote/{id}`,
/// `loop://transaction/{id}`, `loop://protect`, `loop://search`,
/// `loop://settings`, `loop://profile`
nonisolated enum DeepLinkRouter {
    static let authCallbackHost = "login-callback"

    static func isAuthCallback(_ url: URL) -> Bool {
        url.scheme?.lowercased() == LoopConfiguration.oauthURLScheme && url.host?.lowercased() == authCallbackHost
    }

    static func parse(_ url: URL) -> LoopDeepLink? {
        guard url.scheme?.lowercased() == LoopConfiguration.urlScheme else { return nil }
        guard let host = url.host?.lowercased() else { return nil }
        let identifier = url.pathComponents.first(where: { $0 != "/" }).flatMap(UUID.init(uuidString:))

        switch host {
        case "today": return .tab(.today)
        case "money": return .tab(.money)
        case "sell": return .tab(.sell)
        case "business": return .tab(.business)
        case "ask", "askloop": return .tab(.askLoop)
        case "search": return .search

        case "protect": return .destination(.protect, tab: .money)
        case "purchases": return .destination(.purchases, tab: .money)
        case "transactions": return .destination(.transactions, tab: .money)
        case "returns": return .destination(.returns, tab: .money)
        case "refunds": return .destination(.refunds, tab: .money)
        case "warranties": return .destination(.warranties, tab: .money)
        case "documents": return .destination(.documents, tab: .money)
        case "leads": return .destination(.leads, tab: .business)
        case "customers": return .destination(.customers, tab: .business)
        case "opportunities": return .destination(.opportunities, tab: .business)
        case "quotes": return .destination(.quotes, tab: .business)
        case "earnings": return .destination(.earnings, tab: .business)
        case "profile": return .destination(.profile, tab: .today)
        case "settings": return .destination(.settings, tab: .today)
        case "help": return .destination(.help, tab: .today)

        case "purchase":
            return identifier.map { .destination(.purchase($0), tab: .money) }
        case "transaction":
            return identifier.map { .destination(.transaction($0), tab: .money) }
        case "return":
            return identifier.map { .destination(.returnDetail($0), tab: .money) }
        case "refund":
            return identifier.map { .destination(.refund($0), tab: .money) }
        case "warranty":
            return identifier.map { .destination(.warranty($0), tab: .money) }
        case "item":
            return identifier.map { .destination(.ownedItem($0), tab: .sell) }
        case "sale":
            return identifier.map { .destination(.sale($0), tab: .sell) }
        case "lead":
            return identifier.map { .destination(.lead($0), tab: .business) }
        case "customer":
            return identifier.map { .destination(.customer($0), tab: .business) }
        case "opportunity":
            return identifier.map { .destination(.opportunity($0), tab: .business) }
        case "quote":
            return identifier.map { .destination(.quote($0), tab: .business) }

        default:
            return nil
        }
    }
}
