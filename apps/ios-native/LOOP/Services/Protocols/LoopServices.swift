import Foundation

// MARK: - Authentication & account

@MainActor
protocol AuthService: AnyObject {
    /// Restores a stored session at launch. Returns nil when signed out.
    func restoreSession() async throws -> LoopSession?
    /// Runs the browser-based OAuth/PKCE leg and exchanges the code for a session.
    func signInWithGoogle() async throws -> LoopSession
    /// Handles an OAuth redirect delivered to the app.
    func handleCallback(url: URL) async throws -> LoopSession
    func signOut() async throws
}

@MainActor
protocol AccountService: AnyObject {
    /// Loads the profile, accounts and onboarding state for a session.
    func loadProfile(session: LoopSession) async throws -> LoopProfile
    func completeOnboarding(
        profile: LoopProfile,
        displayName: String,
        username: String,
        password: String,
        accountName: String
    ) async throws -> LoopProfile
    func switchAccount(profile: LoopProfile, to accountID: UUID) async throws -> LoopProfile
}

// MARK: - Today

@MainActor
protocol TodayService: AnyObject {
    func digest(accountID: UUID) async throws -> TodayDigest
    func complete(actionID: UUID, accountID: UUID) async throws
    func restore(actionID: UUID, accountID: UUID) async throws
}

// MARK: - Money

@MainActor
protocol MoneyService: AnyObject {
    func summary(accountID: UUID) async throws -> MoneySummary
    func transactions(accountID: UUID) async throws -> [MoneyTransaction]
    func transaction(id: UUID, accountID: UUID) async throws -> MoneyTransaction
}

// MARK: - Purchases & owned items

@MainActor
protocol PurchaseService: AnyObject {
    func purchases(accountID: UUID) async throws -> [Purchase]
    func purchase(id: UUID, accountID: UUID) async throws -> Purchase
    /// Creates a purchase through the server-authoritative money RPC.
    func create(purchase: Purchase) async throws -> Purchase
    func ownedItems(accountID: UUID) async throws -> [OwnedItem]
    func ownedItem(id: UUID, accountID: UUID) async throws -> OwnedItem
    func update(purchase: Purchase) async throws -> Purchase
    func update(ownedItem: OwnedItem) async throws -> OwnedItem
}

// MARK: - Protect

@MainActor
protocol ProtectionService: AnyObject {
    func overview(accountID: UUID) async throws -> ProtectOverview
}

@MainActor
protocol ReturnService: AnyObject {
    func returns(accountID: UUID) async throws -> [ReturnRecord]
    func returnRecord(id: UUID, accountID: UUID) async throws -> ReturnRecord
    func startReturn(purchaseID: UUID, reason: String, accountID: UUID) async throws -> ReturnRecord
    func advance(returnID: UUID, to status: ReturnStatus, accountID: UUID) async throws -> ReturnRecord
    func update(returnRecord: ReturnRecord) async throws -> ReturnRecord
}

@MainActor
protocol RefundService: AnyObject {
    func refunds(accountID: UUID) async throws -> [Refund]
    func refund(id: UUID, accountID: UUID) async throws -> Refund
    func markReceived(refundID: UUID, amount: MoneyAmount, accountID: UUID) async throws -> Refund
    func update(refund: Refund) async throws -> Refund
}

@MainActor
protocol WarrantyService: AnyObject {
    func warranties(accountID: UUID) async throws -> [Warranty]
    func warranty(id: UUID, accountID: UUID) async throws -> Warranty
    func save(warranty: Warranty) async throws -> Warranty
    func archive(warrantyID: UUID, accountID: UUID) async throws
}

@MainActor
protocol DocumentService: AnyObject {
    func documents(accountID: UUID) async throws -> [LoopDocument]
    func documents(for target: DocumentAttachmentTarget, accountID: UUID) async throws -> [LoopDocument]
    func attach(document: LoopDocument) async throws -> LoopDocument
    func remove(documentID: UUID, accountID: UUID) async throws
    /// Resolves a time-limited URL for viewing. Storage provider stays behind this call.
    func downloadURL(for documentID: UUID, accountID: UUID) async throws -> URL
}

// MARK: - Sell

@MainActor
protocol ResaleService: AnyObject {
    func summary(accountID: UUID) async throws -> ResaleSummary
    func sales(accountID: UUID) async throws -> [SaleRecord]
    func sale(id: UUID, accountID: UUID) async throws -> SaleRecord
    func save(sale: SaleRecord) async throws -> SaleRecord
    func markSold(saleID: UUID, accountID: UUID) async throws -> SaleRecord
    func markForSale(ownedItemID: UUID, accountID: UUID) async throws -> OwnedItem
}

// MARK: - Business

@MainActor
protocol BusinessService: AnyObject {
    func summary(accountID: UUID) async throws -> BusinessSummary
    func earnings(accountID: UUID) async throws -> [BusinessEarning]
    func recordEarning(_ earning: BusinessEarning) async throws -> BusinessEarning
}

@MainActor
protocol LeadService: AnyObject {
    func leads(accountID: UUID) async throws -> [Lead]
    func lead(id: UUID, accountID: UUID) async throws -> Lead
    func save(lead: Lead) async throws -> Lead
    func archive(leadID: UUID, accountID: UUID) async throws
    /// Converts a qualified lead into an opportunity, linking both records.
    func convertToOpportunity(leadID: UUID, accountID: UUID) async throws -> Opportunity
}

@MainActor
protocol OpportunityService: AnyObject {
    func opportunities(accountID: UUID) async throws -> [Opportunity]
    func opportunity(id: UUID, accountID: UUID) async throws -> Opportunity
    func save(opportunity: Opportunity) async throws -> Opportunity
    func setStage(opportunityID: UUID, stage: OpportunityStage, accountID: UUID) async throws -> Opportunity
    func archive(opportunityID: UUID, accountID: UUID) async throws
}

@MainActor
protocol QuoteService: AnyObject {
    func quotes(accountID: UUID) async throws -> [Quote]
    func quote(id: UUID, accountID: UUID) async throws -> Quote
    func save(quote: Quote) async throws -> Quote
    func setStatus(quoteID: UUID, status: QuoteStatus, accountID: UUID) async throws -> Quote
    func duplicate(quoteID: UUID, accountID: UUID) async throws -> Quote
    func archive(quoteID: UUID, accountID: UUID) async throws
    func nextReference(accountID: UUID) async throws -> String
}

@MainActor
protocol CustomerService: AnyObject {
    func customers(accountID: UUID) async throws -> [Customer]
    func customer(id: UUID, accountID: UUID) async throws -> Customer
    func save(customer: Customer) async throws -> Customer
    func archive(customerID: UUID, accountID: UUID) async throws
}

// MARK: - Ask LOOP & search

@MainActor
protocol AskLoopService: AnyObject {
    /// True only when LOOP's server-side intelligence is reachable and configured.
    var isLiveIntelligenceAvailable: Bool { get }
    func send(message: String, accountID: UUID) async throws -> AskLoopResponse
}

@MainActor
protocol SearchService: AnyObject {
    func search(query: String, category: SearchCategory, accountID: UUID) async throws -> [SearchResult]
}

// MARK: - Protect overview

nonisolated struct ProtectOverview: Hashable, Sendable {
    var activeReturnWindows: [Purchase]
    var openReturns: [ReturnRecord]
    var outstandingRefunds: [Refund]
    var expiringWarranties: [Warranty]
    var missingReceipts: [Purchase]
    var recentlyProtected: [ReturnRecord]
    var moneyAtStake: MoneyAmount
    var recoveredAllTime: MoneyAmount

    static let empty = ProtectOverview(
        activeReturnWindows: [],
        openReturns: [],
        outstandingRefunds: [],
        expiringWarranties: [],
        missingReceipts: [],
        recentlyProtected: [],
        moneyAtStake: .zero,
        recoveredAllTime: .zero
    )
}
