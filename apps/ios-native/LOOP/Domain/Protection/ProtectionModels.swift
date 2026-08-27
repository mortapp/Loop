import Foundation

// MARK: - Returns

nonisolated enum ReturnStatus: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case eligible
    case started
    case packaged
    case shipped
    case merchantReceived
    case refundPending
    case refunded
    case rejected
    case expired
    case cancelled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eligible: return "Eligible"
        case .started: return "Started"
        case .packaged: return "Packaged"
        case .shipped: return "Shipped"
        case .merchantReceived: return "Merchant received"
        case .refundPending: return "Refund pending"
        case .refunded: return "Refunded"
        case .rejected: return "Rejected"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        }
    }

    var tone: LoopTone {
        switch self {
        case .eligible: return .info
        case .started, .packaged, .shipped, .merchantReceived: return .accent
        case .refundPending: return .caution
        case .refunded: return .positive
        case .rejected, .expired: return .critical
        case .cancelled: return .neutral
        }
    }

    var symbolName: String {
        switch self {
        case .eligible: return "checkmark.circle"
        case .started: return "play.circle"
        case .packaged: return "shippingbox"
        case .shipped: return "paperplane"
        case .merchantReceived: return "building.2"
        case .refundPending: return "clock"
        case .refunded: return "checkmark.seal"
        case .rejected: return "xmark.octagon"
        case .expired: return "clock.badge.xmark"
        case .cancelled: return "slash.circle"
        }
    }

    /// Position in the happy-path lifecycle, or nil for terminal/failed states.
    var lifecycleIndex: Int? {
        switch self {
        case .eligible: return 0
        case .started: return 1
        case .packaged: return 2
        case .shipped: return 3
        case .merchantReceived: return 4
        case .refundPending: return 5
        case .refunded: return 6
        default: return nil
        }
    }

    var isOpen: Bool {
        switch self {
        case .started, .packaged, .shipped, .merchantReceived, .refundPending: return true
        default: return false
        }
    }

    /// The next status a user can advance to manually.
    var nextStep: ReturnStatus? {
        switch self {
        case .eligible: return .started
        case .started: return .packaged
        case .packaged: return .shipped
        case .shipped: return .merchantReceived
        case .merchantReceived: return .refundPending
        default: return nil
        }
    }
}

nonisolated struct ReturnRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var purchaseID: UUID
    var itemName: String
    var merchant: String
    var status: ReturnStatus
    var reason: String?
    var startedAt: Date
    var deadline: Date?
    var carrier: String?
    var trackingNumber: String?
    var shippedAt: Date?
    var merchantReceivedAt: Date?
    var expectedRefund: MoneyAmount
    var refundID: UUID?
    var documentIDs: [UUID]
    var note: String?

    var timeline: [LoopTimelineStep] {
        let stages: [(ReturnStatus, String, Date?)] = [
            (.started, "Return started", startedAt),
            (.packaged, "Package prepared", nil),
            (.shipped, "Package shipped", shippedAt),
            (.merchantReceived, "Merchant received", merchantReceivedAt),
            (.refundPending, "Refund processing", nil),
            (.refunded, "Refund received", nil)
        ]
        let currentIndex = status.lifecycleIndex ?? -1
        return stages.map { stage, title, date in
            let index = stage.lifecycleIndex ?? 0
            let state: LoopTimelineStep.State
            if status == .rejected || status == .cancelled {
                state = index <= currentIndex ? .complete : .failed
            } else if index < currentIndex {
                state = .complete
            } else if index == currentIndex {
                state = status == .refunded ? .complete : .current
            } else {
                state = .upcoming
            }
            return LoopTimelineStep(id: stage.rawValue, title: title, date: date, state: state)
        }
    }
}

// MARK: - Refunds

nonisolated enum RefundStatus: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case expected
    case pending
    case processing
    case received
    case partial
    case failed
    case disputed
    case cancelled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .expected: return "Expected"
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .received: return "Received"
        case .partial: return "Partial"
        case .failed: return "Failed"
        case .disputed: return "Disputed"
        case .cancelled: return "Cancelled"
        }
    }

    var tone: LoopTone {
        switch self {
        case .expected: return .info
        case .pending, .processing: return .caution
        case .received: return .positive
        case .partial: return .accent
        case .failed, .disputed: return .critical
        case .cancelled: return .neutral
        }
    }

    var symbolName: String {
        switch self {
        case .expected: return "calendar"
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .received: return "checkmark.seal"
        case .partial: return "circle.lefthalf.filled"
        case .failed: return "xmark.octagon"
        case .disputed: return "exclamationmark.bubble"
        case .cancelled: return "slash.circle"
        }
    }

    var isOutstanding: Bool {
        switch self {
        case .expected, .pending, .processing, .partial, .disputed: return true
        default: return false
        }
    }

    var isSettled: Bool { self == .received }
}

nonisolated struct Refund: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var merchant: String
    var itemName: String
    var purchaseID: UUID?
    var returnRecordID: UUID?
    var expectedAmount: MoneyAmount
    var receivedAmount: MoneyAmount?
    var status: RefundStatus
    var expectedDate: Date?
    var receivedDate: Date?
    var openedAt: Date
    var transactionID: UUID?
    var note: String?

    /// Days the refund has been outstanding.
    var ageInDays: Int { LoopDate.daysElapsed(since: openedAt) }

    /// LOOP treats a refund as overdue when it is 14+ days old or past its
    /// expected date by more than 3 days.
    var isOverdue: Bool {
        guard status.isOutstanding else { return false }
        if let expectedDate, LoopDate.daysRemaining(until: expectedDate) < -3 { return true }
        return ageInDays >= 14
    }

    var settledAmount: MoneyAmount { receivedAmount ?? .zero }
}

// MARK: - Warranties

nonisolated enum WarrantyStatus: String, Codable, Hashable, Sendable {
    case active
    case expiring
    case expired
    case unknown

    var label: String {
        switch self {
        case .active: return "Active"
        case .expiring: return "Expiring"
        case .expired: return "Expired"
        case .unknown: return "Unknown"
        }
    }

    var tone: LoopTone {
        switch self {
        case .active: return .positive
        case .expiring: return .caution
        case .expired: return .neutral
        case .unknown: return .info
        }
    }

    var symbolName: String {
        switch self {
        case .active: return "shield.lefthalf.filled"
        case .expiring: return "shield.lefthalf.filled.badge.checkmark"
        case .expired: return "shield.slash"
        case .unknown: return "questionmark.circle"
        }
    }
}

nonisolated enum WarrantyKind: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case manufacturer
    case extended
    case retailer
    case cardBenefit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manufacturer: return "Manufacturer"
        case .extended: return "Extended plan"
        case .retailer: return "Retailer"
        case .cardBenefit: return "Card benefit"
        }
    }
}

nonisolated struct Warranty: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var ownedItemID: UUID?
    var itemName: String
    var provider: String
    var kind: WarrantyKind
    var coverageStart: Date
    var coverageEnd: Date?
    var referenceNumber: String?
    var documentIDs: [UUID]
    var note: String?

    var daysRemaining: Int? {
        guard let coverageEnd else { return nil }
        return LoopDate.daysRemaining(until: coverageEnd)
    }

    var status: WarrantyStatus {
        guard let days = daysRemaining else { return .unknown }
        if days < 0 { return .expired }
        if days <= 45 { return .expiring }
        return .active
    }

    /// 0...1 progress through the coverage period, for the expiry bar.
    var coverageProgress: Double {
        guard let coverageEnd else { return 0 }
        let total = coverageEnd.timeIntervalSince(coverageStart)
        guard total > 0 else { return 1 }
        let elapsed = Date().timeIntervalSince(coverageStart)
        return min(max(elapsed / total, 0), 1)
    }
}
