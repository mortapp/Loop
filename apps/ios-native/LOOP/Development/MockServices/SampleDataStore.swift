import Foundation

/// In-memory, mutable LOOP account used by the sample environment.
///
/// DEVELOPMENT INFRASTRUCTURE. This type is never referenced by production
/// services; it exists so LOOP is fully explorable before a backend is attached.
/// Every mutation mirrors the real domain rules (net proceeds, refund
/// reconciliation, ledger writes), so behaviour matches the live contract.
@MainActor
final class SampleDataStore {
    static let shared = SampleDataStore()

    private(set) var snapshot: LoopDataSnapshot
    private let engine = TodayRuleEngine.standard

    init(snapshot: LoopDataSnapshot = LoopFixtures.snapshot) {
        self.snapshot = snapshot
    }

    // MARK: - Reads

    var profile: LoopProfile { snapshot.profile }

    func digest() -> TodayDigest {
        engine.digest(from: snapshot.context(), completedActionIDs: snapshot.completedActionIDs)
    }

    func moneySummary() -> MoneySummary {
        let calendar = LoopDate.calendar
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: Date())
        ) ?? Date()
        let monthly = snapshot.transactions.filter { $0.occurredAt >= monthStart }
        let cleared = monthly.filter { $0.status == .cleared }

        let incoming = MoneyAmount.sum(
            cleared.filter { $0.direction == .incoming }.map(\.amount)
        )
        let outgoing = MoneyAmount.sum(
            cleared.filter { $0.direction == .outgoing }.map(\.amount)
        )
        let recovered = MoneyAmount.sum(
            cleared.filter { $0.type.isRecovery }.map(\.amount)
        )
        let business = MoneyAmount.sum(
            cleared.filter { $0.type == .businessIncome }.map(\.amount)
        )
        let resale = MoneyAmount.sum(
            cleared.filter { $0.type == .resale }.map(\.amount)
        )
        let pending = MoneyAmount.sum(
            monthly.filter { $0.status == .pending && $0.direction == .incoming }.map(\.amount)
        )

        return MoneySummary(
            netMovement: incoming - outgoing,
            incoming: incoming,
            outgoing: outgoing,
            recovered: recovered,
            businessEarnings: business,
            resaleProceeds: resale,
            pendingIncoming: pending,
            periodLabel: Date().formatted(.dateTime.month(.wide))
        )
    }

    func protectOverview() -> ProtectOverview {
        let activeWindows = snapshot.purchases
            .filter { ($0.returnWindow?.isExpired == false) }
            .sorted { ($0.returnWindow?.deadline ?? .distantFuture) < ($1.returnWindow?.deadline ?? .distantFuture) }
        let openReturns = snapshot.returns.filter(\.status.isOpen)
        let outstanding = snapshot.refunds.filter(\.status.isOutstanding)
        let expiring = snapshot.warranties.filter { $0.status == .expiring }
        let missing = activeWindows.filter { !snapshot.context().hasReceipt(purchaseID: $0.id) }
        let recovered = MoneyAmount.sum(
            snapshot.refunds.filter { $0.status == .received }.map(\.settledAmount)
        )
        return ProtectOverview(
            activeReturnWindows: activeWindows,
            openReturns: openReturns,
            outstandingRefunds: outstanding,
            expiringWarranties: expiring,
            missingReceipts: missing,
            recentlyProtected: snapshot.returns.filter { $0.status == .refunded },
            moneyAtStake: MoneyAmount.sum(outstanding.map(\.expectedAmount)),
            recoveredAllTime: recovered
        )
    }

    func resaleSummary() -> ResaleSummary {
        let sales = snapshot.sales
        let saleItemIDs = Set(sales.filter { $0.status != .cancelled }.map(\.ownedItemID))
        let candidates = snapshot.ownedItems
            .filter { !$0.isSold && !saleItemIDs.contains($0.id) }
            .filter { $0.estimatedResaleValue != nil || $0.ageInDays >= 180 }
            .map { item in
                ResaleCandidate(
                    item: item,
                    reason: item.ageInDays >= 365
                        ? "Owned for over a year"
                        : "Owned for \(item.ageInDays) days",
                    estimate: item.estimatedResaleValue,
                    estimateIsUserProvided: item.estimateIsUserProvided
                )
            }
        let sold = sales.filter { $0.status == .sold }
        let yearStart = LoopDate.calendar.date(
            from: LoopDate.calendar.dateComponents([.year], from: Date())
        ) ?? Date()
        let proceeds = MoneyAmount.sum(
            sold.filter { ($0.soldDate ?? .distantPast) >= yearStart }.map(\.netProceeds)
        )
        return ResaleSummary(
            readyToSell: candidates,
            drafts: sales.filter { $0.status == .draft },
            listed: sales.filter { $0.status == .listed },
            pending: sales.filter { $0.status == .pending },
            sold: sold.sorted { ($0.soldDate ?? .distantPast) > ($1.soldDate ?? .distantPast) },
            proceedsThisYear: proceeds,
            estimatedPotential: MoneyAmount.sum(candidates.compactMap(\.estimate))
        )
    }

    func businessSummary() -> BusinessSummary {
        let leads = snapshot.leads.filter { !$0.isArchived }
        let opportunities = snapshot.opportunities.filter { !$0.isArchived }
        let quotes = snapshot.quotes.filter { !$0.isArchived }
        let yearStart = LoopDate.calendar.date(
            from: LoopDate.calendar.dateComponents([.year], from: Date())
        ) ?? Date()
        let awaiting = quotes.filter(\.status.isAwaitingResponse)
        return BusinessSummary(
            newLeads: leads.filter { $0.status == .new }.count,
            openLeads: leads.filter(\.status.isOpen).count,
            activeOpportunities: opportunities.filter(\.stage.isActive).count,
            pipelineValue: MoneyAmount.sum(
                opportunities.filter(\.stage.isActive).map(\.estimatedValue)
            ),
            quotesAwaitingResponse: awaiting.count,
            quotedValue: MoneyAmount.sum(awaiting.map(\.total)),
            wonThisYear: opportunities.filter { $0.stage == .won }.count,
            earningsThisYear: MoneyAmount.sum(
                snapshot.earnings.filter { $0.receivedAt >= yearStart }.map(\.amount)
            ),
            nextFollowUps: leads
                .filter { $0.status.isOpen && $0.nextFollowUp != nil }
                .sorted { ($0.nextFollowUp ?? .distantFuture) < ($1.nextFollowUp ?? .distantFuture) }
        )
    }

    // MARK: - Today mutations

    func completeAction(_ id: UUID) {
        snapshot.completedActionIDs[id] = Date()
    }

    func restoreAction(_ id: UUID) {
        snapshot.completedActionIDs.removeValue(forKey: id)
    }

    // MARK: - Profile

    func updateProfile(_ profile: LoopProfile) {
        snapshot.profile = profile
    }

    // MARK: - Purchases

    func upsert(purchase: Purchase) {
        if let index = snapshot.purchases.firstIndex(where: { $0.id == purchase.id }) {
            snapshot.purchases[index] = purchase
        } else {
            snapshot.purchases.append(purchase)
        }
    }

    func upsert(ownedItem: OwnedItem) {
        if let index = snapshot.ownedItems.firstIndex(where: { $0.id == ownedItem.id }) {
            snapshot.ownedItems[index] = ownedItem
        } else {
            snapshot.ownedItems.append(ownedItem)
        }
    }

    // MARK: - Returns and refunds

    func startReturn(purchaseID: UUID, reason: String) throws -> ReturnRecord {
        guard let purchase = snapshot.purchases.first(where: { $0.id == purchaseID }) else {
            throw LoopError.notFound
        }
        let record = ReturnRecord(
            id: UUID(),
            accountID: purchase.accountID,
            purchaseID: purchase.id,
            itemName: purchase.itemName,
            merchant: purchase.merchant,
            status: .started,
            reason: reason.isEmpty ? nil : reason,
            startedAt: Date(),
            deadline: purchase.returnWindow?.deadline,
            carrier: nil,
            trackingNumber: nil,
            shippedAt: nil,
            merchantReceivedAt: nil,
            expectedRefund: purchase.amount,
            refundID: nil,
            documentIDs: [],
            note: nil
        )
        snapshot.returns.append(record)
        if let index = snapshot.ownedItems.firstIndex(where: { $0.purchaseID == purchaseID }) {
            snapshot.ownedItems[index].returnRecordID = record.id
        }
        return record
    }

    func advanceReturn(id: UUID, to status: ReturnStatus) throws -> ReturnRecord {
        guard let index = snapshot.returns.firstIndex(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        var record = snapshot.returns[index]
        record.status = status
        switch status {
        case .shipped: record.shippedAt = Date()
        case .merchantReceived: record.merchantReceivedAt = Date()
        case .refundPending:
            if record.refundID == nil {
                let refund = makeRefund(for: record)
                record.refundID = refund.id
            }
        case .refunded:
            if let refundID = record.refundID {
                _ = try? markRefundReceived(id: refundID, amount: record.expectedRefund)
            }
        default: break
        }
        snapshot.returns[index] = record
        return record
    }

    private func makeRefund(for record: ReturnRecord) -> Refund {
        let transaction = MoneyTransaction(
            id: UUID(),
            accountID: record.accountID,
            amount: record.expectedRefund,
            direction: .incoming,
            type: .refund,
            title: "\(record.merchant) refund",
            merchantOrSource: record.merchant,
            category: "Recovered",
            occurredAt: Date(),
            status: .pending,
            relatedRecord: nil,
            note: nil
        )
        let refund = Refund(
            id: UUID(),
            accountID: record.accountID,
            merchant: record.merchant,
            itemName: record.itemName,
            purchaseID: record.purchaseID,
            returnRecordID: record.id,
            expectedAmount: record.expectedRefund,
            receivedAmount: nil,
            status: .pending,
            expectedDate: LoopDate.adding(days: 10, to: Date()),
            receivedDate: nil,
            openedAt: Date(),
            transactionID: transaction.id,
            note: nil
        )
        var linkedTransaction = transaction
        linkedTransaction.relatedRecord = .refund(refund.id)
        snapshot.transactions.append(linkedTransaction)
        snapshot.refunds.append(refund)
        return refund
    }

    func upsert(returnRecord: ReturnRecord) {
        if let index = snapshot.returns.firstIndex(where: { $0.id == returnRecord.id }) {
            snapshot.returns[index] = returnRecord
        } else {
            snapshot.returns.append(returnRecord)
        }
    }

    @discardableResult
    func markRefundReceived(id: UUID, amount: MoneyAmount) throws -> Refund {
        guard let index = snapshot.refunds.firstIndex(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        var refund = snapshot.refunds[index]
        refund.receivedAmount = amount
        refund.status = amount.value < refund.expectedAmount.value ? .partial : .received
        refund.receivedDate = Date()
        snapshot.refunds[index] = refund

        if let transactionID = refund.transactionID,
           let transactionIndex = snapshot.transactions.firstIndex(where: { $0.id == transactionID }) {
            snapshot.transactions[transactionIndex].status = .cleared
            snapshot.transactions[transactionIndex].amount = amount
            snapshot.transactions[transactionIndex].occurredAt = Date()
        }
        if let returnIndex = snapshot.returns.firstIndex(where: { $0.refundID == refund.id }) {
            snapshot.returns[returnIndex].status = .refunded
        }
        return refund
    }

    func upsert(refund: Refund) {
        if let index = snapshot.refunds.firstIndex(where: { $0.id == refund.id }) {
            snapshot.refunds[index] = refund
        } else {
            snapshot.refunds.append(refund)
        }
    }

    // MARK: - Warranties

    func upsert(warranty: Warranty) {
        if let index = snapshot.warranties.firstIndex(where: { $0.id == warranty.id }) {
            snapshot.warranties[index] = warranty
        } else {
            snapshot.warranties.append(warranty)
            if let itemID = warranty.ownedItemID,
               let itemIndex = snapshot.ownedItems.firstIndex(where: { $0.id == itemID }) {
                snapshot.ownedItems[itemIndex].warrantyID = warranty.id
            }
        }
    }

    func removeWarranty(id: UUID) {
        snapshot.warranties.removeAll { $0.id == id }
        for index in snapshot.ownedItems.indices where snapshot.ownedItems[index].warrantyID == id {
            snapshot.ownedItems[index].warrantyID = nil
        }
    }

    // MARK: - Documents

    func attach(document: LoopDocument) {
        snapshot.documents.append(document)
        switch document.target {
        case .returnRecord(let id):
            if let index = snapshot.returns.firstIndex(where: { $0.id == id }) {
                snapshot.returns[index].documentIDs.append(document.id)
            }
        case .warranty(let id):
            if let index = snapshot.warranties.firstIndex(where: { $0.id == id }) {
                snapshot.warranties[index].documentIDs.append(document.id)
            }
        default:
            break
        }
    }

    func removeDocument(id: UUID) {
        snapshot.documents.removeAll { $0.id == id }
        for index in snapshot.returns.indices {
            snapshot.returns[index].documentIDs.removeAll { $0 == id }
        }
        for index in snapshot.warranties.indices {
            snapshot.warranties[index].documentIDs.removeAll { $0 == id }
        }
    }

    // MARK: - Sales

    func upsert(sale: SaleRecord) {
        if let index = snapshot.sales.firstIndex(where: { $0.id == sale.id }) {
            snapshot.sales[index] = sale
        } else {
            snapshot.sales.append(sale)
        }
        if let itemIndex = snapshot.ownedItems.firstIndex(where: { $0.id == sale.ownedItemID }) {
            snapshot.ownedItems[itemIndex].isMarkedForSale = sale.status != .cancelled
        }
    }

    func markSold(saleID: UUID) throws -> SaleRecord {
        guard let index = snapshot.sales.firstIndex(where: { $0.id == saleID }) else {
            throw LoopError.notFound
        }
        var sale = snapshot.sales[index]
        guard sale.status != .sold else { return sale }
        sale.status = .sold
        sale.soldDate = Date()

        let transaction = MoneyTransaction(
            id: UUID(),
            accountID: sale.accountID,
            amount: sale.netProceeds,
            direction: .incoming,
            type: .resale,
            title: "\(sale.itemName) resale",
            merchantOrSource: sale.platform,
            category: "Resale",
            occurredAt: Date(),
            status: .cleared,
            relatedRecord: .sale(sale.id),
            note: sale.totalCosts.isZero
                ? nil
                : "Net of \(MoneyFormatter.string(sale.fees)) fees and \(MoneyFormatter.string(sale.shippingCost)) shipping."
        )
        snapshot.transactions.append(transaction)
        sale.transactionID = transaction.id
        snapshot.sales[index] = sale

        if let itemIndex = snapshot.ownedItems.firstIndex(where: { $0.id == sale.ownedItemID }) {
            snapshot.ownedItems[itemIndex].saleID = sale.id
        }
        return sale
    }

    func markForSale(ownedItemID: UUID) throws -> OwnedItem {
        guard let index = snapshot.ownedItems.firstIndex(where: { $0.id == ownedItemID }) else {
            throw LoopError.notFound
        }
        snapshot.ownedItems[index].isMarkedForSale = true
        return snapshot.ownedItems[index]
    }

    // MARK: - Business

    func upsert(customer: Customer) {
        if let index = snapshot.customers.firstIndex(where: { $0.id == customer.id }) {
            snapshot.customers[index] = customer
        } else {
            snapshot.customers.append(customer)
        }
    }

    func upsert(lead: Lead) {
        if let index = snapshot.leads.firstIndex(where: { $0.id == lead.id }) {
            snapshot.leads[index] = lead
        } else {
            snapshot.leads.append(lead)
        }
    }

    func convertLead(id: UUID) throws -> Opportunity {
        guard let index = snapshot.leads.firstIndex(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        var lead = snapshot.leads[index]
        if let existingID = lead.opportunityID,
           let existing = snapshot.opportunities.first(where: { $0.id == existingID }) {
            return existing
        }
        var customerID = lead.customerID
        if customerID == nil {
            let customer = Customer(
                id: UUID(),
                accountID: lead.accountID,
                name: lead.name,
                company: nil,
                email: lead.contactLabel?.contains("@") == true ? lead.contactLabel : nil,
                phone: lead.contactLabel?.contains("@") == false ? lead.contactLabel : nil,
                note: nil,
                createdAt: Date(),
                isArchived: false
            )
            snapshot.customers.append(customer)
            customerID = customer.id
        }
        let opportunity = Opportunity(
            id: UUID(),
            accountID: lead.accountID,
            title: "\(lead.name) opportunity",
            detail: lead.note,
            customerID: customerID,
            leadID: lead.id,
            estimatedValue: lead.estimatedValue ?? .zero,
            stage: .open,
            expectedCloseDate: LoopDate.adding(days: 21, to: Date()),
            quoteIDs: [],
            note: nil,
            createdAt: Date(),
            isArchived: false
        )
        snapshot.opportunities.append(opportunity)
        lead.status = .converted
        lead.customerID = customerID
        lead.opportunityID = opportunity.id
        lead.nextFollowUp = nil
        snapshot.leads[index] = lead
        return opportunity
    }

    func upsert(opportunity: Opportunity) {
        if let index = snapshot.opportunities.firstIndex(where: { $0.id == opportunity.id }) {
            snapshot.opportunities[index] = opportunity
        } else {
            snapshot.opportunities.append(opportunity)
        }
    }

    func upsert(quote: Quote) {
        if let index = snapshot.quotes.firstIndex(where: { $0.id == quote.id }) {
            snapshot.quotes[index] = quote
        } else {
            snapshot.quotes.append(quote)
        }
        if let opportunityID = quote.opportunityID,
           let index = snapshot.opportunities.firstIndex(where: { $0.id == opportunityID }),
           !snapshot.opportunities[index].quoteIDs.contains(quote.id) {
            snapshot.opportunities[index].quoteIDs.append(quote.id)
        }
    }

    /// Accepting a quote advances its linked opportunity to Won. Income is only
    /// recorded when the user explicitly records it.
    func setQuoteStatus(id: UUID, status: QuoteStatus) throws -> Quote {
        guard let index = snapshot.quotes.firstIndex(where: { $0.id == id }) else {
            throw LoopError.notFound
        }
        var quote = snapshot.quotes[index]
        quote.status = status
        if status == .accepted || status == .declined {
            quote.respondedAt = Date()
        }
        snapshot.quotes[index] = quote

        if let opportunityID = quote.opportunityID,
           let oppIndex = snapshot.opportunities.firstIndex(where: { $0.id == opportunityID }) {
            if status == .accepted { snapshot.opportunities[oppIndex].stage = .won }
            if status == .declined { snapshot.opportunities[oppIndex].stage = .lost }
        }
        return quote
    }

    func nextQuoteReference() -> String {
        let numbers = snapshot.quotes.compactMap { quote -> Int? in
            Int(quote.reference.split(separator: "-").last.map(String.init) ?? "")
        }
        return "Q-\((numbers.max() ?? 1000) + 1)"
    }

    @discardableResult
    func recordEarning(_ earning: BusinessEarning) -> BusinessEarning {
        var earning = earning
        let transaction = MoneyTransaction(
            id: UUID(),
            accountID: earning.accountID,
            amount: earning.amount,
            direction: .incoming,
            type: .businessIncome,
            title: earning.title,
            merchantOrSource: snapshot.customers.first(where: { $0.id == earning.customerID })?.displayName,
            category: "Business",
            occurredAt: earning.receivedAt,
            status: .cleared,
            relatedRecord: .earning(earning.id),
            note: earning.note
        )
        snapshot.transactions.append(transaction)
        earning.transactionID = transaction.id
        snapshot.earnings.append(earning)
        return earning
    }

    // MARK: - Search

    func search(query: String, category: SearchCategory) -> [SearchResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 1 else { return [] }

        func matches(_ values: String?...) -> Bool {
            values.compactMap { $0 }.contains { $0.localizedStandardContains(needle) }
        }

        var results: [SearchResult] = []

        if category == .all || category == .money {
            results += snapshot.transactions
                .filter { matches($0.title, $0.merchantOrSource, $0.category) }
                .map {
                    SearchResult(
                        id: $0.id,
                        title: $0.title,
                        subtitle: "\($0.type.label) · \(LoopDate.medium($0.occurredAt))",
                        symbolName: $0.type.symbolName,
                        tone: $0.direction == .incoming ? .positive : .neutral,
                        category: .money,
                        source: .transaction($0.id),
                        amount: $0.signedAmount
                    )
                }
            results += snapshot.purchases
                .filter { matches($0.itemName, $0.merchant, $0.orderNumber, $0.category) }
                .map {
                    SearchResult(
                        id: $0.id,
                        title: $0.itemName,
                        subtitle: "Purchase · \($0.merchant)",
                        symbolName: "bag",
                        tone: .neutral,
                        category: .money,
                        source: .purchase($0.id),
                        amount: $0.amount
                    )
                }
        }

        if category == .all || category == .protect {
            results += snapshot.returns
                .filter { matches($0.itemName, $0.merchant, $0.trackingNumber) }
                .map {
                    SearchResult(
                        id: $0.id,
                        title: $0.itemName,
                        subtitle: "Return · \($0.status.label)",
                        symbolName: $0.status.symbolName,
                        tone: $0.status.tone,
                        category: .protect,
                        source: .returnRecord($0.id),
                        amount: $0.expectedRefund
                    )
                }
            results += snapshot.refunds
                .filter { matches($0.itemName, $0.merchant) }
                .map {
                    SearchResult(
                        id: $0.id,
                        title: "\($0.merchant) refund",
                        subtitle: "Refund · \($0.status.label)",
                        symbolName: $0.status.symbolName,
                        tone: $0.status.tone,
                        category: .protect,
                        source: .refund($0.id),
                        amount: $0.expectedAmount
                    )
                }
            results += snapshot.warranties
                .filter { matches($0.itemName, $0.provider, $0.referenceNumber) }
                .map {
                    SearchResult(
                        id: $0.id,
                        title: $0.itemName,
                        subtitle: "Warranty · \($0.status.label)",
                        symbolName: $0.status.symbolName,
                        tone: $0.status.tone,
                        category: .protect,
                        source: .warranty($0.id),
                        amount: nil
                    )
                }
        }

        if category == .all || category == .sell {
            results += snapshot.sales
                .filter { matches($0.itemName, $0.platform) }
                .map {
                    SearchResult(
                        id: $0.id,
                        title: $0.itemName,
                        subtitle: "Sale · \($0.status.label)",
                        symbolName: $0.status.symbolName,
                        tone: $0.status.tone,
                        category: .sell,
                        source: .sale($0.id),
                        amount: $0.netProceeds
                    )
                }
            results += snapshot.ownedItems
                .filter { matches($0.name, $0.merchant) }
                .map {
                    SearchResult(
                        id: $0.id,
                        title: $0.name,
                        subtitle: "Owned item · \($0.condition.label)",
                        symbolName: "shippingbox",
                        tone: .neutral,
                        category: .sell,
                        source: .ownedItem($0.id),
                        amount: $0.estimatedResaleValue
                    )
                }
        }

        if category == .all || category == .business {
            results += snapshot.leads
                .filter { matches($0.name, $0.contactLabel, $0.note) }
                .map {
                    SearchResult(
                        id: $0.id,
                        title: $0.name,
                        subtitle: "Lead · \($0.status.label)",
                        symbolName: $0.status.symbolName,
                        tone: $0.status.tone,
                        category: .business,
                        source: .lead($0.id),
                        amount: $0.estimatedValue
                    )
                }
            results += snapshot.opportunities
                .filter { matches($0.title, $0.detail) }
                .map {
                    SearchResult(
                        id: $0.id,
                        title: $0.title,
                        subtitle: "Opportunity · \($0.stage.label)",
                        symbolName: $0.stage.symbolName,
                        tone: $0.stage.tone,
                        category: .business,
                        source: .opportunity($0.id),
                        amount: $0.estimatedValue
                    )
                }
            results += snapshot.quotes
                .filter { matches($0.title, $0.reference) }
                .map {
                    SearchResult(
                        id: $0.id,
                        title: "\($0.reference) · \($0.title)",
                        subtitle: "Quote · \($0.status.label)",
                        symbolName: $0.status.symbolName,
                        tone: $0.status.tone,
                        category: .business,
                        source: .quote($0.id),
                        amount: $0.total
                    )
                }
        }

        return results
    }
}
