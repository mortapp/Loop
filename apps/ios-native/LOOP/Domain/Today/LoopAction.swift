import Foundation

nonisolated enum ActionPriority: String, Codable, Hashable, Sendable, CaseIterable, Comparable {
    case urgent
    case high
    case normal
    case informational

    var label: String {
        switch self {
        case .urgent: return "Urgent"
        case .high: return "Soon"
        case .normal: return "Opportunity"
        case .informational: return "Info"
        }
    }

    var symbolName: String {
        switch self {
        case .urgent: return "exclamationmark.2"
        case .high: return "clock.badge.exclamationmark"
        case .normal: return "arrow.up.right"
        case .informational: return "info"
        }
    }

    var tone: LoopTone {
        switch self {
        case .urgent: return .critical
        case .high: return .caution
        case .normal: return .accent
        case .informational: return .info
        }
    }

    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .normal: return 2
        case .informational: return 3
        }
    }

    static func < (lhs: ActionPriority, rhs: ActionPriority) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

nonisolated enum LoopActionType: String, Codable, Hashable, Sendable {
    case returnWindowClosing
    case returnWindowExpired
    case refundPending
    case refundOverdue
    case refundReceived
    case receiptMissing
    case warrantyExpiring
    case leadFollowUp
    case quoteAwaitingResponse
    case quoteExpiringSoon
    case opportunityNeedsAttention
    case resaleOpportunity
    case saleFollowUp
    case earningsRecorded

    var symbolName: String {
        switch self {
        case .returnWindowClosing, .returnWindowExpired: return "arrow.uturn.backward"
        case .refundPending, .refundOverdue: return "arrow.down.left.circle"
        case .refundReceived: return "checkmark.seal"
        case .receiptMissing: return "doc.text.magnifyingglass"
        case .warrantyExpiring: return "shield.lefthalf.filled"
        case .leadFollowUp: return "person.crop.circle.badge.clock"
        case .quoteAwaitingResponse, .quoteExpiringSoon: return "doc.plaintext"
        case .opportunityNeedsAttention: return "chart.line.uptrend.xyaxis"
        case .resaleOpportunity: return "tag"
        case .saleFollowUp: return "shippingbox"
        case .earningsRecorded: return "dollarsign.circle"
        }
    }
}

/// Which LOOP record an action came from — drives navigation on tap.
nonisolated enum ActionSource: Codable, Hashable, Sendable {
    case purchase(UUID)
    case returnRecord(UUID)
    case refund(UUID)
    case warranty(UUID)
    case ownedItem(UUID)
    case sale(UUID)
    case customer(UUID)
    case lead(UUID)
    case opportunity(UUID)
    case quote(UUID)
    case transaction(UUID)

    var destination: AppDestination {
        switch self {
        case .purchase(let id): return .purchase(id)
        case .returnRecord(let id): return .returnDetail(id)
        case .refund(let id): return .refund(id)
        case .warranty(let id): return .warranty(id)
        case .ownedItem(let id): return .ownedItem(id)
        case .sale(let id): return .sale(id)
        case .customer(let id): return .customer(id)
        case .lead(let id): return .lead(id)
        case .opportunity(let id): return .opportunity(id)
        case .quote(let id): return .quote(id)
        case .transaction(let id): return .transaction(id)
        }
    }

    /// The tab that owns this record, so Today routes into the right stack.
    var owningTab: LoopTab {
        switch self {
        case .purchase, .returnRecord, .refund, .warranty, .transaction:
            return .money
        case .ownedItem, .sale:
            return .sell
        case .customer, .lead, .opportunity, .quote:
            return .business
        }
    }
}

/// A single prioritized thing LOOP believes the user should do.
nonisolated struct LoopAction: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    let type: LoopActionType
    var title: String
    var subtitle: String?
    var priority: ActionPriority
    var dueDate: Date?
    var amount: MoneyAmount?
    var source: ActionSource
    var createdAt: Date
    var completedAt: Date?

    var isCompleted: Bool { completedAt != nil }

    /// Sorting key: priority first, then nearest deadline.
    var sortKey: (Int, TimeInterval) {
        (priority.sortOrder, dueDate?.timeIntervalSince1970 ?? .greatestFiniteMagnitude)
    }
}

/// Grouped Today feed.
nonisolated struct TodayDigest: Sendable, Hashable {
    var date: Date
    var needsAttention: [LoopAction]
    var dueSoon: [LoopAction]
    var opportunities: [LoopAction]
    var information: [LoopAction]
    var recentlyCompleted: [LoopAction]
    var moneyAtStake: MoneyAmount
    var recoveredThisMonth: MoneyAmount

    var openActionCount: Int {
        needsAttention.count + dueSoon.count + opportunities.count + information.count
    }

    var isClear: Bool { openActionCount == 0 }

    static let empty = TodayDigest(
        date: Date(),
        needsAttention: [],
        dueSoon: [],
        opportunities: [],
        information: [],
        recentlyCompleted: [],
        moneyAtStake: .zero,
        recoveredThisMonth: .zero
    )
}
