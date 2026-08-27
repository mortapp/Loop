import Foundation

// MARK: - Customers

nonisolated struct Customer: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var name: String
    var company: String?
    var email: String?
    var phone: String?
    var note: String?
    var createdAt: Date
    var isArchived: Bool

    var displayName: String { company.map { "\(name) · \($0)" } ?? name }

    var initials: String {
        let source = company?.isEmpty == false ? (company ?? name) : name
        let parts = source.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

// MARK: - Leads

nonisolated enum LeadStatus: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case new
    case contacted
    case qualified
    case unqualified
    case converted
    case lost

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new: return "New"
        case .contacted: return "Contacted"
        case .qualified: return "Qualified"
        case .unqualified: return "Unqualified"
        case .converted: return "Converted"
        case .lost: return "Lost"
        }
    }

    var tone: LoopTone {
        switch self {
        case .new: return .accent
        case .contacted: return .info
        case .qualified: return .positive
        case .unqualified, .lost: return .neutral
        case .converted: return .positive
        }
    }

    var symbolName: String {
        switch self {
        case .new: return "sparkle"
        case .contacted: return "phone"
        case .qualified: return "checkmark.circle"
        case .unqualified: return "minus.circle"
        case .converted: return "arrow.turn.up.right"
        case .lost: return "xmark.circle"
        }
    }

    var isOpen: Bool {
        switch self {
        case .new, .contacted, .qualified: return true
        default: return false
        }
    }
}

nonisolated enum LeadSource: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case referral
    case website
    case socialMedia
    case repeatCustomer
    case walkIn
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .referral: return "Referral"
        case .website: return "Website"
        case .socialMedia: return "Social"
        case .repeatCustomer: return "Repeat customer"
        case .walkIn: return "Walk-in"
        case .other: return "Other"
        }
    }
}

nonisolated struct Lead: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var name: String
    var contactLabel: String?
    var source: LeadSource
    var status: LeadStatus
    var estimatedValue: MoneyAmount?
    var note: String?
    var createdAt: Date
    var nextFollowUp: Date?
    var customerID: UUID?
    var opportunityID: UUID?
    var isArchived: Bool

    var isFollowUpDue: Bool {
        guard status.isOpen, let nextFollowUp else { return false }
        return LoopDate.daysRemaining(until: nextFollowUp) <= 0
    }
}

// MARK: - Opportunities

nonisolated enum OpportunityStage: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case open
    case proposal
    case negotiation
    case won
    case lost
    case cancelled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: return "Open"
        case .proposal: return "Proposal"
        case .negotiation: return "Negotiation"
        case .won: return "Won"
        case .lost: return "Lost"
        case .cancelled: return "Cancelled"
        }
    }

    var tone: LoopTone {
        switch self {
        case .open: return .info
        case .proposal: return .accent
        case .negotiation: return .caution
        case .won: return .positive
        case .lost, .cancelled: return .neutral
        }
    }

    var symbolName: String {
        switch self {
        case .open: return "circle.dashed"
        case .proposal: return "doc.plaintext"
        case .negotiation: return "bubble.left.and.bubble.right"
        case .won: return "trophy"
        case .lost: return "xmark.circle"
        case .cancelled: return "slash.circle"
        }
    }

    var isActive: Bool {
        switch self {
        case .open, .proposal, .negotiation: return true
        default: return false
        }
    }
}

nonisolated struct Opportunity: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var title: String
    var detail: String?
    var customerID: UUID?
    var leadID: UUID?
    var estimatedValue: MoneyAmount
    var stage: OpportunityStage
    var expectedCloseDate: Date?
    var quoteIDs: [UUID]
    var note: String?
    var createdAt: Date
    var isArchived: Bool

    var needsAttention: Bool {
        guard stage.isActive, let expectedCloseDate else { return false }
        return LoopDate.daysRemaining(until: expectedCloseDate) <= 3
    }
}

// MARK: - Quotes

nonisolated enum QuoteStatus: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case draft
    case sent
    case viewed
    case accepted
    case declined
    case expired
    case cancelled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft: return "Draft"
        case .sent: return "Sent"
        case .viewed: return "Viewed"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        }
    }

    var tone: LoopTone {
        switch self {
        case .draft: return .neutral
        case .sent: return .info
        case .viewed: return .accent
        case .accepted: return .positive
        case .declined, .expired: return .critical
        case .cancelled: return .neutral
        }
    }

    var symbolName: String {
        switch self {
        case .draft: return "pencil"
        case .sent: return "paperplane"
        case .viewed: return "eye"
        case .accepted: return "checkmark.seal"
        case .declined: return "hand.thumbsdown"
        case .expired: return "clock.badge.xmark"
        case .cancelled: return "slash.circle"
        }
    }

    var isAwaitingResponse: Bool { self == .sent || self == .viewed }
}

nonisolated struct QuoteLineItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var detail: String?
    var quantity: Decimal
    var unitPrice: Decimal

    /// quantity × unit price, rounded to currency precision.
    var lineTotal: Decimal { MoneyFormatter.rounded(quantity * unitPrice) }

    init(
        id: UUID = UUID(),
        name: String,
        detail: String? = nil,
        quantity: Decimal = 1,
        unitPrice: Decimal = 0
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.quantity = quantity
        self.unitPrice = unitPrice
    }
}

nonisolated struct Quote: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var reference: String
    var title: String
    var customerID: UUID?
    var opportunityID: UUID?
    var lineItems: [QuoteLineItem]
    var discount: Decimal
    var taxRate: Decimal
    var currencyCode: String
    var status: QuoteStatus
    var issuedAt: Date
    var expiresAt: Date?
    var respondedAt: Date?
    var note: String?
    var isArchived: Bool

    /// Sum of all line totals.
    var subtotal: MoneyAmount {
        let value = lineItems.reduce(Decimal(0)) { $0 + $1.lineTotal }
        return MoneyAmount(MoneyFormatter.rounded(value), currencyCode: currencyCode)
    }

    /// Subtotal minus discount, never below zero.
    var discountedSubtotal: MoneyAmount {
        let value = max(subtotal.value - discount, 0)
        return MoneyAmount(MoneyFormatter.rounded(value), currencyCode: currencyCode)
    }

    var taxAmount: MoneyAmount {
        let value = discountedSubtotal.value * taxRate
        return MoneyAmount(MoneyFormatter.rounded(value), currencyCode: currencyCode)
    }

    /// Final amount owed by the customer.
    var total: MoneyAmount {
        let value = discountedSubtotal.value + taxAmount.value
        return MoneyAmount(MoneyFormatter.rounded(value), currencyCode: currencyCode)
    }

    var isExpired: Bool {
        guard let expiresAt, status.isAwaitingResponse else { return false }
        return LoopDate.daysRemaining(until: expiresAt) < 0
    }

    var expiresSoon: Bool {
        guard let expiresAt, status.isAwaitingResponse else { return false }
        let days = LoopDate.daysRemaining(until: expiresAt)
        return days >= 0 && days <= 5
    }

    var timeline: [LoopTimelineStep] {
        let sentState: LoopTimelineStep.State = status == .draft ? .upcoming : .complete
        let viewedState: LoopTimelineStep.State
        switch status {
        case .draft: viewedState = .upcoming
        case .sent: viewedState = .current
        default: viewedState = .complete
        }
        let decisionState: LoopTimelineStep.State
        switch status {
        case .accepted: decisionState = .complete
        case .declined, .expired, .cancelled: decisionState = .failed
        default: decisionState = .upcoming
        }
        return [
            LoopTimelineStep(id: "draft", title: "Quote prepared", date: issuedAt, state: .complete),
            LoopTimelineStep(id: "sent", title: "Sent to customer", state: sentState),
            LoopTimelineStep(id: "viewed", title: "Customer viewed", state: viewedState),
            LoopTimelineStep(
                id: "decision",
                title: status == .declined ? "Declined" : "Accepted",
                date: respondedAt,
                state: decisionState
            )
        ]
    }
}

// MARK: - Earnings

nonisolated enum EarningSource: String, Codable, Hashable, Sendable {
    case quote
    case opportunity
    case manual

    var label: String {
        switch self {
        case .quote: return "From quote"
        case .opportunity: return "From opportunity"
        case .manual: return "Recorded manually"
        }
    }
}

/// Business income recorded in LOOP. Always mirrored into the Money ledger —
/// Business never keeps a separate balance of its own.
nonisolated struct BusinessEarning: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var title: String
    var customerID: UUID?
    var opportunityID: UUID?
    var quoteID: UUID?
    var amount: MoneyAmount
    var receivedAt: Date
    var source: EarningSource
    var transactionID: UUID?
    var note: String?
}

/// Business dashboard roll-up.
nonisolated struct BusinessSummary: Hashable, Sendable {
    var newLeads: Int
    var openLeads: Int
    var activeOpportunities: Int
    var pipelineValue: MoneyAmount
    var quotesAwaitingResponse: Int
    var quotedValue: MoneyAmount
    var wonThisYear: Int
    var earningsThisYear: MoneyAmount
    var nextFollowUps: [Lead]

    static let empty = BusinessSummary(
        newLeads: 0,
        openLeads: 0,
        activeOpportunities: 0,
        pipelineValue: .zero,
        quotesAwaitingResponse: 0,
        quotedValue: .zero,
        wonThisYear: 0,
        earningsThisYear: .zero,
        nextFollowUps: []
    )
}
