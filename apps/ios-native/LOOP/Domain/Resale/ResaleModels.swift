import Foundation

nonisolated enum SaleStatus: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case draft
    case listed
    case pending
    case sold
    case cancelled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft: return "Draft"
        case .listed: return "Listed"
        case .pending: return "Pending"
        case .sold: return "Sold"
        case .cancelled: return "Cancelled"
        }
    }

    var tone: LoopTone {
        switch self {
        case .draft: return .neutral
        case .listed: return .info
        case .pending: return .caution
        case .sold: return .positive
        case .cancelled: return .neutral
        }
    }

    var symbolName: String {
        switch self {
        case .draft: return "pencil"
        case .listed: return "megaphone"
        case .pending: return "clock"
        case .sold: return "checkmark.seal"
        case .cancelled: return "slash.circle"
        }
    }

    var lifecycleIndex: Int? {
        switch self {
        case .draft: return 0
        case .listed: return 1
        case .pending: return 2
        case .sold: return 3
        case .cancelled: return nil
        }
    }
}

/// A resale of an owned item. Net proceeds settle into Money.
nonisolated struct SaleRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var ownedItemID: UUID
    var itemName: String
    var platform: String?
    var grossAmount: MoneyAmount
    var fees: MoneyAmount
    var shippingCost: MoneyAmount
    var listedDate: Date?
    var soldDate: Date?
    var status: SaleStatus
    var transactionID: UUID?
    var note: String?

    /// gross − fees − shipping.
    var netProceeds: MoneyAmount {
        MoneyAmount(
            grossAmount.value - fees.value - shippingCost.value,
            currencyCode: grossAmount.currencyCode
        )
    }

    /// Total deductions taken off the gross amount.
    var totalCosts: MoneyAmount {
        MoneyAmount(fees.value + shippingCost.value, currencyCode: grossAmount.currencyCode)
    }

    var timeline: [LoopTimelineStep] {
        let stages: [(SaleStatus, String, Date?)] = [
            (.draft, "Sale drafted", nil),
            (.listed, "Listed for sale", listedDate),
            (.pending, "Buyer committed", nil),
            (.sold, "Sold and paid", soldDate)
        ]
        let currentIndex = status.lifecycleIndex ?? -1
        return stages.map { stage, title, date in
            let index = stage.lifecycleIndex ?? 0
            let state: LoopTimelineStep.State
            if status == .cancelled {
                state = index <= currentIndex ? .complete : .failed
            } else if index < currentIndex {
                state = .complete
            } else if index == currentIndex {
                state = status == .sold ? .complete : .current
            } else {
                state = .upcoming
            }
            return LoopTimelineStep(id: stage.rawValue, title: title, date: date, state: state)
        }
    }
}

/// An item LOOP believes could be turned back into money.
nonisolated struct ResaleCandidate: Identifiable, Hashable, Sendable {
    let item: OwnedItem
    var reason: String
    var estimate: MoneyAmount?
    var estimateIsUserProvided: Bool

    var id: UUID { item.id }
}

/// Sell dashboard roll-up.
nonisolated struct ResaleSummary: Hashable, Sendable {
    var readyToSell: [ResaleCandidate]
    var drafts: [SaleRecord]
    var listed: [SaleRecord]
    var pending: [SaleRecord]
    var sold: [SaleRecord]
    var proceedsThisYear: MoneyAmount
    var estimatedPotential: MoneyAmount

    static let empty = ResaleSummary(
        readyToSell: [],
        drafts: [],
        listed: [],
        pending: [],
        sold: [],
        proceedsThisYear: .zero,
        estimatedPotential: .zero
    )
}
