import Foundation

nonisolated enum SearchCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case money
    case protect
    case sell
    case business

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Everything"
        case .money: return "Money"
        case .protect: return "Protect"
        case .sell: return "Sell"
        case .business: return "Business"
        }
    }
}

/// A single unified search hit across every LOOP module.
nonisolated struct SearchResult: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var subtitle: String
    var symbolName: String
    var tone: LoopTone
    var category: SearchCategory
    var source: ActionSource
    var amount: MoneyAmount?
}
