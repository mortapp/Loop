import Foundation

nonisolated enum ItemCondition: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case new
    case likeNew
    case good
    case fair
    case poor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new: return "New"
        case .likeNew: return "Like new"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Worn"
        }
    }
}

/// A purchase the user made. The junction point of the whole LOOP lifecycle.
nonisolated struct Purchase: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var itemName: String
    var merchant: String
    var amount: MoneyAmount
    var purchasedAt: Date
    var category: String?
    var orderNumber: String?
    var returnWindow: ReturnWindow?
    var note: String?
    var transactionID: UUID?
    var ownedItemID: UUID?

    var hasReturnWindow: Bool { returnWindow != nil }
}

/// Something the user owns — created from a purchase, consumed by Protect and Sell.
nonisolated struct OwnedItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var name: String
    var merchant: String
    var purchaseID: UUID?
    var purchasedAt: Date
    var originalPrice: MoneyAmount
    var condition: ItemCondition
    var estimatedResaleValue: MoneyAmount?
    var estimateIsUserProvided: Bool
    var warrantyID: UUID?
    var returnRecordID: UUID?
    var saleID: UUID?
    var isMarkedForSale: Bool
    var note: String?

    var ageInDays: Int { LoopDate.daysElapsed(since: purchasedAt) }

    var isSold: Bool { saleID != nil }
}

/// The merchant's return policy applied to a purchase.
nonisolated struct ReturnWindow: Codable, Hashable, Sendable {
    var purchasedAt: Date
    var policyDays: Int
    var policyNote: String?
    var extendedDeadline: Date?

    var deadline: Date {
        extendedDeadline ?? LoopDate.adding(days: policyDays, to: purchasedAt)
    }

    var daysRemaining: Int { LoopDate.daysRemaining(until: deadline) }

    var isExpired: Bool { daysRemaining < 0 }

    var isClosingSoon: Bool { daysRemaining >= 0 && daysRemaining <= 7 }

    var state: State {
        if isExpired { return .expired }
        if daysRemaining <= 2 { return .closingImmediately }
        if isClosingSoon { return .closingSoon }
        return .open
    }

    nonisolated enum State: String, Hashable, Sendable {
        case open
        case closingSoon
        case closingImmediately
        case expired

        var label: String {
            switch self {
            case .open: return "Returnable"
            case .closingSoon: return "Closing soon"
            case .closingImmediately: return "Closing now"
            case .expired: return "Window closed"
            }
        }

        var tone: LoopTone {
            switch self {
            case .open: return .positive
            case .closingSoon: return .caution
            case .closingImmediately: return .critical
            case .expired: return .neutral
            }
        }
    }
}
