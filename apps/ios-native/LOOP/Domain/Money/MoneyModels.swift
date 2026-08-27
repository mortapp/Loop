import Foundation

nonisolated enum TransactionDirection: String, Codable, Hashable, Sendable {
    case incoming
    case outgoing

    var sign: Decimal { self == .incoming ? 1 : -1 }
}

nonisolated enum MoneyTransactionType: String, Codable, Hashable, Sendable, CaseIterable {
    case income
    case purchase
    case refund
    case resale
    case businessIncome
    case fee
    case adjustment
    case other

    var label: String {
        switch self {
        case .income: return "Income"
        case .purchase: return "Purchase"
        case .refund: return "Refund"
        case .resale: return "Resale"
        case .businessIncome: return "Business"
        case .fee: return "Fee"
        case .adjustment: return "Adjustment"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .income: return "arrow.down.left"
        case .purchase: return "bag"
        case .refund: return "arrow.uturn.backward"
        case .resale: return "tag"
        case .businessIncome: return "briefcase"
        case .fee: return "minus.circle"
        case .adjustment: return "slider.horizontal.3"
        case .other: return "circle.dotted"
        }
    }

    /// Money the user got back rather than earned fresh.
    var isRecovery: Bool { self == .refund }
}

nonisolated enum TransactionStatus: String, Codable, Hashable, Sendable {
    case pending
    case cleared
    case failed
    case cancelled

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .cleared: return "Cleared"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var tone: LoopTone {
        switch self {
        case .pending: return .caution
        case .cleared: return .positive
        case .failed: return .critical
        case .cancelled: return .neutral
        }
    }

    var symbolName: String {
        switch self {
        case .pending: return "clock"
        case .cleared: return "checkmark"
        case .failed: return "xmark"
        case .cancelled: return "slash.circle"
        }
    }
}

/// A pointer from a Money transaction back into the record that produced it.
nonisolated enum RelatedRecordReference: Codable, Hashable, Sendable {
    case purchase(UUID)
    case refund(UUID)
    case sale(UUID)
    case earning(UUID)
    case quote(UUID)

    var destination: AppDestination {
        switch self {
        case .purchase(let id): return .purchase(id)
        case .refund(let id): return .refund(id)
        case .sale(let id): return .sale(id)
        case .earning(let id): return .earnings
        case .quote(let id): return .quote(id)
        }
    }

    var label: String {
        switch self {
        case .purchase: return "View purchase"
        case .refund: return "View refund"
        case .sale: return "View sale"
        case .earning: return "View earnings"
        case .quote: return "View quote"
        }
    }
}

nonisolated struct MoneyTransaction: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var amount: MoneyAmount
    var direction: TransactionDirection
    var type: MoneyTransactionType
    var title: String
    var merchantOrSource: String?
    var category: String?
    var occurredAt: Date
    var status: TransactionStatus
    var relatedRecord: RelatedRecordReference?
    var note: String?

    /// Signed amount: outgoing values are negative.
    var signedAmount: MoneyAmount {
        MoneyAmount(amount.absolute.value * direction.sign, currencyCode: amount.currencyCode)
    }
}

/// Roll-up shown at the top of Money.
nonisolated struct MoneySummary: Hashable, Sendable {
    var netMovement: MoneyAmount
    var incoming: MoneyAmount
    var outgoing: MoneyAmount
    var recovered: MoneyAmount
    var businessEarnings: MoneyAmount
    var resaleProceeds: MoneyAmount
    var pendingIncoming: MoneyAmount
    var periodLabel: String

    static let empty = MoneySummary(
        netMovement: .zero,
        incoming: .zero,
        outgoing: .zero,
        recovered: .zero,
        businessEarnings: .zero,
        resaleProceeds: .zero,
        pendingIncoming: .zero,
        periodLabel: "This month"
    )
}

/// Filters available in the Money ledger.
nonisolated enum MoneyFilter: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case incoming
    case outgoing
    case recovered
    case business
    case resale
    case pending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .incoming: return "In"
        case .outgoing: return "Out"
        case .recovered: return "Recovered"
        case .business: return "Business"
        case .resale: return "Resale"
        case .pending: return "Pending"
        }
    }

    func matches(_ transaction: MoneyTransaction) -> Bool {
        switch self {
        case .all: return true
        case .incoming: return transaction.direction == .incoming
        case .outgoing: return transaction.direction == .outgoing
        case .recovered: return transaction.type.isRecovery
        case .business: return transaction.type == .businessIncome
        case .resale: return transaction.type == .resale
        case .pending: return transaction.status == .pending
        }
    }
}
