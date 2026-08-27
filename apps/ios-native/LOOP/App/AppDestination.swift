import Foundation

/// The five primary LOOP tabs. Never add a sixth.
nonisolated enum LoopTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case today
    case money
    case sell
    case business
    case askLoop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .money: return "Money"
        case .sell: return "Sell"
        case .business: return "Business"
        case .askLoop: return "Ask LOOP"
        }
    }

    var symbolName: String {
        switch self {
        case .today: return "sun.horizon"
        case .money: return "arrow.left.arrow.right"
        case .sell: return "tag"
        case .business: return "briefcase"
        case .askLoop: return "sparkle"
        }
    }

    var selectedSymbolName: String {
        switch self {
        case .today: return "sun.horizon.fill"
        case .money: return "arrow.left.arrow.right"
        case .sell: return "tag.fill"
        case .business: return "briefcase.fill"
        case .askLoop: return "sparkles"
        }
    }
}

/// Strongly typed navigation destinations pushed onto per-tab stacks.
nonisolated enum AppDestination: Hashable, Sendable {
    // Money
    case transactions
    case transaction(UUID)
    case purchases
    case purchase(UUID)

    // Protect
    case protect
    case returns
    case returnDetail(UUID)
    case refunds
    case refund(UUID)
    case warranties
    case warranty(UUID)
    case documents
    case ownedItem(UUID)

    // Sell
    case sales
    case sale(UUID)

    // Business
    case leads
    case lead(UUID)
    case customers
    case customer(UUID)
    case opportunities
    case opportunity(UUID)
    case quotes
    case quote(UUID)
    case earnings

    // Account
    case profile
    case settings
    case personalization
    case help
    case about

    var analyticsName: String {
        switch self {
        case .transactions: return "transactions"
        case .transaction: return "transaction"
        case .purchases: return "purchases"
        case .purchase: return "purchase"
        case .protect: return "protect"
        case .returns: return "returns"
        case .returnDetail: return "return"
        case .refunds: return "refunds"
        case .refund: return "refund"
        case .warranties: return "warranties"
        case .warranty: return "warranty"
        case .documents: return "documents"
        case .ownedItem: return "owned_item"
        case .sales: return "sales"
        case .sale: return "sale"
        case .leads: return "leads"
        case .lead: return "lead"
        case .customers: return "customers"
        case .customer: return "customer"
        case .opportunities: return "opportunities"
        case .opportunity: return "opportunity"
        case .quotes: return "quotes"
        case .quote: return "quote"
        case .earnings: return "earnings"
        case .profile: return "profile"
        case .settings: return "settings"
        case .personalization: return "personalization"
        case .help: return "help"
        case .about: return "about"
        }
    }
}

/// Sheets presented above the tab shell.
nonisolated enum AppSheet: Identifiable, Hashable, Sendable {
    case search
    case newLead
    case newOpportunity(leadID: UUID?)
    case newQuote(customerID: UUID?)
    case newCustomer
    case newSale(ownedItemID: UUID?)
    case editWarranty(ownedItemID: UUID, warrantyID: UUID?)
    case startReturn(purchaseID: UUID)
    case attachDocument(DocumentAttachmentTarget)

    var id: String {
        switch self {
        case .search: return "search"
        case .newLead: return "newLead"
        case .newOpportunity(let id): return "newOpportunity-\(id?.uuidString ?? "none")"
        case .newQuote(let id): return "newQuote-\(id?.uuidString ?? "none")"
        case .newCustomer: return "newCustomer"
        case .newSale(let id): return "newSale-\(id?.uuidString ?? "none")"
        case .editWarranty(let item, let warranty):
            return "warranty-\(item.uuidString)-\(warranty?.uuidString ?? "new")"
        case .startReturn(let id): return "startReturn-\(id.uuidString)"
        case .attachDocument(let target): return "attach-\(target.id)"
        }
    }
}
