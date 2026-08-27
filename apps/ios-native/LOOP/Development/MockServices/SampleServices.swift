import Foundation

/// DEVELOPMENT INFRASTRUCTURE.
///
/// Service implementations backed by `SampleDataStore`. They satisfy exactly the
/// same protocols as the live Supabase-backed services, so swapping environments
/// requires no change in any view or view model.
@MainActor
final class SampleServices {
    let store: SampleDataStore

    init(store: SampleDataStore = .shared) {
        self.store = store
    }

    /// Small artificial latency so loading and skeleton states are exercised.
    fileprivate static func settle() async {
        try? await Task.sleep(for: .milliseconds(220))
    }
}

// MARK: - Auth & account

@MainActor
final class SampleAuthService: AuthService {
    private let store: SampleDataStore
    private var session: LoopSession?

    init(store: SampleDataStore = .shared) {
        self.store = store
    }

    func restoreSession() async throws -> LoopSession? {
        await SampleServices.settle()
        return session
    }

    func signInWithGoogle() async throws -> LoopSession {
        await SampleServices.settle()
        let session = LoopSession(
            userID: store.profile.user.id,
            accessToken: "sample-session",
            refreshToken: "sample-refresh",
            expiresAt: LoopDate.adding(days: 30, to: Date())
        )
        self.session = session
        return session
    }

    func handleCallback(url: URL) async throws -> LoopSession {
        try await signInWithGoogle()
    }

    func signOut() async throws {
        session = nil
    }
}

@MainActor
final class SampleAccountService: AccountService {
    private let store: SampleDataStore

    init(store: SampleDataStore = .shared) {
        self.store = store
    }

    func loadProfile(session: LoopSession) async throws -> LoopProfile {
        await SampleServices.settle()
        return store.profile
    }

    func completeOnboarding(
        profile: LoopProfile,
        displayName: String,
        accountName: String
    ) async throws -> LoopProfile {
        var updated = profile
        updated.user.displayName = displayName.isEmpty ? profile.user.displayName : displayName
        if let index = updated.accounts.firstIndex(where: { $0.id == updated.activeAccountID }),
           !accountName.isEmpty {
            updated.accounts[index].name = accountName
        }
        updated.hasCompletedOnboarding = true
        store.updateProfile(updated)
        return updated
    }

    func switchAccount(profile: LoopProfile, to accountID: UUID) async throws -> LoopProfile {
        var updated = profile
        guard updated.accounts.contains(where: { $0.id == accountID }) else { throw LoopError.notFound }
        updated.activeAccountID = accountID
        store.updateProfile(updated)
        return updated
    }
}

// MARK: - Today

@MainActor
final class SampleTodayService: TodayService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func digest(accountID: UUID) async throws -> TodayDigest {
        await SampleServices.settle()
        return store.digest()
    }

    func complete(actionID: UUID, accountID: UUID) async throws {
        store.completeAction(actionID)
    }

    func restore(actionID: UUID, accountID: UUID) async throws {
        store.restoreAction(actionID)
    }
}

// MARK: - Money

@MainActor
final class SampleMoneyService: MoneyService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func summary(accountID: UUID) async throws -> MoneySummary {
        await SampleServices.settle()
        return store.moneySummary()
    }

    func transactions(accountID: UUID) async throws -> [MoneyTransaction] {
        await SampleServices.settle()
        return store.snapshot.transactions.sorted { $0.occurredAt > $1.occurredAt }
    }

    func transaction(id: UUID, accountID: UUID) async throws -> MoneyTransaction {
        guard let match = store.snapshot.transactions.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }
}

// MARK: - Purchases

@MainActor
final class SamplePurchaseService: PurchaseService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func purchases(accountID: UUID) async throws -> [Purchase] {
        await SampleServices.settle()
        return store.snapshot.purchases.sorted { $0.purchasedAt > $1.purchasedAt }
    }

    func purchase(id: UUID, accountID: UUID) async throws -> Purchase {
        guard let match = store.snapshot.purchases.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }

    func ownedItems(accountID: UUID) async throws -> [OwnedItem] {
        await SampleServices.settle()
        return store.snapshot.ownedItems.sorted { $0.purchasedAt > $1.purchasedAt }
    }

    func ownedItem(id: UUID, accountID: UUID) async throws -> OwnedItem {
        guard let match = store.snapshot.ownedItems.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }

    func update(purchase: Purchase) async throws -> Purchase {
        store.upsert(purchase: purchase)
        return purchase
    }

    func update(ownedItem: OwnedItem) async throws -> OwnedItem {
        store.upsert(ownedItem: ownedItem)
        return ownedItem
    }
}

// MARK: - Protect

@MainActor
final class SampleProtectionService: ProtectionService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func overview(accountID: UUID) async throws -> ProtectOverview {
        await SampleServices.settle()
        return store.protectOverview()
    }
}

@MainActor
final class SampleReturnService: ReturnService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func returns(accountID: UUID) async throws -> [ReturnRecord] {
        await SampleServices.settle()
        return store.snapshot.returns.sorted { $0.startedAt > $1.startedAt }
    }

    func returnRecord(id: UUID, accountID: UUID) async throws -> ReturnRecord {
        guard let match = store.snapshot.returns.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }

    func startReturn(purchaseID: UUID, reason: String, accountID: UUID) async throws -> ReturnRecord {
        try store.startReturn(purchaseID: purchaseID, reason: reason)
    }

    func advance(returnID: UUID, to status: ReturnStatus, accountID: UUID) async throws -> ReturnRecord {
        try store.advanceReturn(id: returnID, to: status)
    }

    func update(returnRecord: ReturnRecord) async throws -> ReturnRecord {
        store.upsert(returnRecord: returnRecord)
        return returnRecord
    }
}

@MainActor
final class SampleRefundService: RefundService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func refunds(accountID: UUID) async throws -> [Refund] {
        await SampleServices.settle()
        return store.snapshot.refunds.sorted { $0.openedAt > $1.openedAt }
    }

    func refund(id: UUID, accountID: UUID) async throws -> Refund {
        guard let match = store.snapshot.refunds.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }

    func markReceived(refundID: UUID, amount: MoneyAmount, accountID: UUID) async throws -> Refund {
        try store.markRefundReceived(id: refundID, amount: amount)
    }

    func update(refund: Refund) async throws -> Refund {
        store.upsert(refund: refund)
        return refund
    }
}

@MainActor
final class SampleWarrantyService: WarrantyService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func warranties(accountID: UUID) async throws -> [Warranty] {
        await SampleServices.settle()
        return store.snapshot.warranties.sorted {
            ($0.coverageEnd ?? .distantFuture) < ($1.coverageEnd ?? .distantFuture)
        }
    }

    func warranty(id: UUID, accountID: UUID) async throws -> Warranty {
        guard let match = store.snapshot.warranties.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }

    func save(warranty: Warranty) async throws -> Warranty {
        store.upsert(warranty: warranty)
        return warranty
    }

    func archive(warrantyID: UUID, accountID: UUID) async throws {
        store.removeWarranty(id: warrantyID)
    }
}

@MainActor
final class SampleDocumentService: DocumentService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func documents(accountID: UUID) async throws -> [LoopDocument] {
        await SampleServices.settle()
        return store.snapshot.documents.sorted { $0.createdAt > $1.createdAt }
    }

    func documents(for target: DocumentAttachmentTarget, accountID: UUID) async throws -> [LoopDocument] {
        store.snapshot.documents.filter { $0.target == target }
    }

    func attach(document: LoopDocument) async throws -> LoopDocument {
        store.attach(document: document)
        return document
    }

    func remove(documentID: UUID, accountID: UUID) async throws {
        store.removeDocument(id: documentID)
    }

    func downloadURL(for documentID: UUID, accountID: UUID) async throws -> URL {
        // Sample documents have no stored file — the UI surfaces this honestly.
        throw LoopError.serviceUnavailable(
            "Document storage isn't connected in sample mode, so this file can't be opened."
        )
    }
}

// MARK: - Sell

@MainActor
final class SampleResaleService: ResaleService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func summary(accountID: UUID) async throws -> ResaleSummary {
        await SampleServices.settle()
        return store.resaleSummary()
    }

    func sales(accountID: UUID) async throws -> [SaleRecord] {
        await SampleServices.settle()
        return store.snapshot.sales
    }

    func sale(id: UUID, accountID: UUID) async throws -> SaleRecord {
        guard let match = store.snapshot.sales.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }

    func save(sale: SaleRecord) async throws -> SaleRecord {
        store.upsert(sale: sale)
        return sale
    }

    func markSold(saleID: UUID, accountID: UUID) async throws -> SaleRecord {
        try store.markSold(saleID: saleID)
    }

    func markForSale(ownedItemID: UUID, accountID: UUID) async throws -> OwnedItem {
        try store.markForSale(ownedItemID: ownedItemID)
    }
}

// MARK: - Business

@MainActor
final class SampleBusinessService: BusinessService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func summary(accountID: UUID) async throws -> BusinessSummary {
        await SampleServices.settle()
        return store.businessSummary()
    }

    func earnings(accountID: UUID) async throws -> [BusinessEarning] {
        await SampleServices.settle()
        return store.snapshot.earnings.sorted { $0.receivedAt > $1.receivedAt }
    }

    func recordEarning(_ earning: BusinessEarning) async throws -> BusinessEarning {
        store.recordEarning(earning)
    }
}

@MainActor
final class SampleLeadService: LeadService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func leads(accountID: UUID) async throws -> [Lead] {
        await SampleServices.settle()
        return store.snapshot.leads.filter { !$0.isArchived }.sorted { $0.createdAt > $1.createdAt }
    }

    func lead(id: UUID, accountID: UUID) async throws -> Lead {
        guard let match = store.snapshot.leads.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }

    func save(lead: Lead) async throws -> Lead {
        store.upsert(lead: lead)
        return lead
    }

    func archive(leadID: UUID, accountID: UUID) async throws {
        guard var lead = store.snapshot.leads.first(where: { $0.id == leadID }) else { return }
        lead.isArchived = true
        store.upsert(lead: lead)
    }

    func convertToOpportunity(leadID: UUID, accountID: UUID) async throws -> Opportunity {
        try store.convertLead(id: leadID)
    }
}

@MainActor
final class SampleOpportunityService: OpportunityService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func opportunities(accountID: UUID) async throws -> [Opportunity] {
        await SampleServices.settle()
        return store.snapshot.opportunities.filter { !$0.isArchived }
    }

    func opportunity(id: UUID, accountID: UUID) async throws -> Opportunity {
        guard let match = store.snapshot.opportunities.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }

    func save(opportunity: Opportunity) async throws -> Opportunity {
        store.upsert(opportunity: opportunity)
        return opportunity
    }

    func setStage(opportunityID: UUID, stage: OpportunityStage, accountID: UUID) async throws -> Opportunity {
        guard var opportunity = store.snapshot.opportunities.first(where: { $0.id == opportunityID }) else {
            throw LoopError.notFound
        }
        opportunity.stage = stage
        store.upsert(opportunity: opportunity)
        return opportunity
    }

    func archive(opportunityID: UUID, accountID: UUID) async throws {
        guard var opportunity = store.snapshot.opportunities.first(where: { $0.id == opportunityID }) else { return }
        opportunity.isArchived = true
        store.upsert(opportunity: opportunity)
    }
}

@MainActor
final class SampleQuoteService: QuoteService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func quotes(accountID: UUID) async throws -> [Quote] {
        await SampleServices.settle()
        return store.snapshot.quotes.filter { !$0.isArchived }.sorted { $0.issuedAt > $1.issuedAt }
    }

    func quote(id: UUID, accountID: UUID) async throws -> Quote {
        guard let match = store.snapshot.quotes.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }

    func save(quote: Quote) async throws -> Quote {
        store.upsert(quote: quote)
        return quote
    }

    func setStatus(quoteID: UUID, status: QuoteStatus, accountID: UUID) async throws -> Quote {
        try store.setQuoteStatus(id: quoteID, status: status)
    }

    func duplicate(quoteID: UUID, accountID: UUID) async throws -> Quote {
        guard let original = store.snapshot.quotes.first(where: { $0.id == quoteID }) else {
            throw LoopError.notFound
        }
        var copy = Quote(
            id: UUID(),
            accountID: original.accountID,
            reference: store.nextQuoteReference(),
            title: original.title,
            customerID: original.customerID,
            opportunityID: original.opportunityID,
            lineItems: original.lineItems.map {
                QuoteLineItem(name: $0.name, detail: $0.detail, quantity: $0.quantity, unitPrice: $0.unitPrice)
            },
            discount: original.discount,
            taxRate: original.taxRate,
            currencyCode: original.currencyCode,
            status: .draft,
            issuedAt: Date(),
            expiresAt: LoopDate.adding(days: 30, to: Date()),
            respondedAt: nil,
            note: original.note,
            isArchived: false
        )
        copy.status = .draft
        store.upsert(quote: copy)
        return copy
    }

    func archive(quoteID: UUID, accountID: UUID) async throws {
        guard var quote = store.snapshot.quotes.first(where: { $0.id == quoteID }) else { return }
        quote.isArchived = true
        store.upsert(quote: quote)
    }

    func nextReference(accountID: UUID) async throws -> String {
        store.nextQuoteReference()
    }
}

@MainActor
final class SampleCustomerService: CustomerService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func customers(accountID: UUID) async throws -> [Customer] {
        await SampleServices.settle()
        return store.snapshot.customers.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }

    func customer(id: UUID, accountID: UUID) async throws -> Customer {
        guard let match = store.snapshot.customers.first(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        return match
    }

    func save(customer: Customer) async throws -> Customer {
        store.upsert(customer: customer)
        return customer
    }

    func archive(customerID: UUID, accountID: UUID) async throws {
        guard var customer = store.snapshot.customers.first(where: { $0.id == customerID }) else { return }
        customer.isArchived = true
        store.upsert(customer: customer)
    }
}

// MARK: - Ask LOOP & search

/// Sample answers are derived from real records in the store and are always
/// labelled as sample intelligence. LOOP never presents them as live AI.
@MainActor
final class SampleAskLoopService: AskLoopService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    var isLiveIntelligenceAvailable: Bool { false }

    func send(message: String, accountID: UUID) async throws -> AskLoopResponse {
        try await Task.sleep(for: .milliseconds(650))
        let query = message.lowercased()
        let digest = store.digest()

        if query.contains("return") {
            let soon = store.snapshot.purchases
                .filter { ($0.returnWindow?.isExpired == false) && ($0.returnWindow?.isClosingSoon == true) }
            guard !soon.isEmpty else {
                return AskLoopResponse(
                    text: "No return windows are closing in the next week. The next one to watch is your most recent purchase.",
                    references: [],
                    isLiveIntelligence: false
                )
            }
            let lines = soon.map { purchase in
                "• \(purchase.itemName) at \(purchase.merchant) — \(LoopDate.deadline(purchase.returnWindow!.deadline))"
            }
            return AskLoopResponse(
                text: "\(soon.count) return window\(soon.count == 1 ? "" : "s") closing soon:\n" + lines.joined(separator: "\n"),
                references: soon.map { AskLoopReference(label: $0.itemName, source: .purchase($0.id)) },
                isLiveIntelligence: false
            )
        }

        if query.contains("recover") || query.contains("refund") {
            let received = store.snapshot.refunds.filter { $0.status == .received }
            let outstanding = store.snapshot.refunds.filter(\.status.isOutstanding)
            let recovered = MoneyAmount.sum(received.map(\.settledAmount))
            let atStake = MoneyAmount.sum(outstanding.map(\.expectedAmount))
            return AskLoopResponse(
                text: "You've recovered \(MoneyFormatter.string(recovered)) through LOOP so far. "
                    + "\(MoneyFormatter.string(atStake)) is still outstanding across \(outstanding.count) refund\(outstanding.count == 1 ? "" : "s").",
                references: outstanding.map {
                    AskLoopReference(label: "\($0.merchant) refund", source: .refund($0.id))
                },
                isLiveIntelligence: false
            )
        }

        if query.contains("sell") {
            let summary = store.resaleSummary()
            let names = summary.readyToSell.prefix(4).map { "• \($0.item.name) — \($0.reason)" }
            return AskLoopResponse(
                text: names.isEmpty
                    ? "Nothing in your owned items looks ready to sell yet."
                    : "\(summary.readyToSell.count) item\(summary.readyToSell.count == 1 ? "" : "s") could be worth selling:\n"
                        + names.joined(separator: "\n")
                        + "\n\nEstimates are yours, not live market prices.",
                references: summary.readyToSell.prefix(4).map {
                    AskLoopReference(label: $0.item.name, source: .ownedItem($0.item.id))
                },
                isLiveIntelligence: false
            )
        }

        if query.contains("lead") {
            let due = store.snapshot.leads.filter { $0.status.isOpen && $0.nextFollowUp != nil }
            let lines = due.map { "• \($0.name) — \(LoopDate.relative($0.nextFollowUp!))" }
            return AskLoopResponse(
                text: lines.isEmpty
                    ? "No leads are scheduled for follow-up."
                    : "Leads with follow-ups scheduled:\n" + lines.joined(separator: "\n"),
                references: due.map { AskLoopReference(label: $0.name, source: .lead($0.id)) },
                isLiveIntelligence: false
            )
        }

        if query.contains("quote") {
            let awaiting = store.snapshot.quotes.filter(\.status.isAwaitingResponse)
            let lines = awaiting.map {
                "• \($0.reference) \($0.title) — \(MoneyFormatter.string($0.total)), \($0.status.label.lowercased())"
            }
            return AskLoopResponse(
                text: lines.isEmpty
                    ? "No quotes are waiting on a customer right now."
                    : "\(awaiting.count) quote\(awaiting.count == 1 ? "" : "s") awaiting a response:\n" + lines.joined(separator: "\n"),
                references: awaiting.map { AskLoopReference(label: $0.reference, source: .quote($0.id)) },
                isLiveIntelligence: false
            )
        }

        let top = (digest.needsAttention + digest.dueSoon).prefix(3)
        let lines = top.map { "• \($0.title)" }
        return AskLoopResponse(
            text: lines.isEmpty
                ? "Nothing urgent is open in your LOOP right now. \(MoneyFormatter.string(digest.recoveredThisMonth)) has been recovered this month."
                : "Here's what stands out right now:\n" + lines.joined(separator: "\n")
                    + "\n\n\(MoneyFormatter.string(digest.moneyAtStake)) is currently at stake across pending refunds.",
            references: top.map { AskLoopReference(label: $0.title, source: $0.source) },
            isLiveIntelligence: false
        )
    }
}

@MainActor
final class SampleSearchService: SearchService {
    private let store: SampleDataStore
    init(store: SampleDataStore = .shared) { self.store = store }

    func search(query: String, category: SearchCategory, accountID: UUID) async throws -> [SearchResult] {
        store.search(query: query, category: category)
    }
}
