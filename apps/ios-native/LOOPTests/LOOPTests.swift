//
//  LOOPTests.swift
//  LOOPTests
//

import Testing
import Foundation
@testable import LOOP

// MARK: - Money

struct MoneyTests {

    @Test func sumsWithDecimalPrecision() {
        let amounts = [MoneyAmount.usd(0.1), .usd(0.2), .usd(349.99)]
        #expect(MoneyAmount.sum(amounts).value == Decimal(string: "350.29"))
    }

    @Test func signedFormattingUsesTrueMinus() {
        #expect(MoneyFormatter.signedString(.usd(86.42)).hasPrefix("+"))
        #expect(MoneyFormatter.signedString(.usd(-86.42)).hasPrefix("\u{2212}"))
        #expect(MoneyFormatter.signedString(.usd(0), showsPlus: true).hasPrefix("$"))
    }

    @Test func parsesUserInput() {
        #expect(MoneyFormatter.parse("$1,299.50") == Decimal(string: "1299.50"))
        #expect(MoneyFormatter.parse(" 42 ") == 42)
        #expect(MoneyFormatter.parse("") == nil)
    }

    @Test func roundsToCurrencyScale() {
        #expect(MoneyFormatter.rounded(Decimal(string: "10.005")!) == Decimal(string: "10.01"))
        #expect(MoneyFormatter.rounded(Decimal(string: "10.004")!) == Decimal(string: "10.00"))
    }

    @Test func transactionSignsByDirection() {
        let outgoing = MoneyTransaction(
            id: UUID(), accountID: UUID(), amount: .usd(50), direction: .outgoing,
            type: .purchase, title: "Test", merchantOrSource: nil, category: nil,
            occurredAt: Date(), status: .cleared, relatedRecord: nil, note: nil
        )
        #expect(outgoing.signedAmount.value == -50)
        #expect(outgoing.signedAmount.isNegative)
    }
}

// MARK: - Quotes

struct QuoteTests {

    private func makeQuote(
        items: [QuoteLineItem],
        discount: Decimal = 0,
        taxRate: Decimal = 0
    ) -> Quote {
        Quote(
            id: UUID(), accountID: UUID(), reference: "Q-1000", title: "Test",
            customerID: nil, opportunityID: nil, lineItems: items,
            discount: discount, taxRate: taxRate, currencyCode: "USD",
            status: .draft, issuedAt: Date(), expiresAt: nil, respondedAt: nil,
            note: nil, isArchived: false
        )
    }

    @Test func lineTotalMultipliesQuantity() {
        let item = QuoteLineItem(name: "Build", quantity: 6, unitPrice: 55)
        #expect(item.lineTotal == 330)
    }

    @Test func subtotalSumsLineItems() {
        let quote = makeQuote(items: [
            QuoteLineItem(name: "Design", quantity: 1, unitPrice: 450),
            QuoteLineItem(name: "Build", quantity: 6, unitPrice: 55),
            QuoteLineItem(name: "Handover", quantity: 1, unitPrice: 45)
        ])
        #expect(quote.subtotal.value == 825)
        #expect(quote.total.value == 825)
    }

    @Test func discountNeverPushesTotalNegative() {
        let quote = makeQuote(
            items: [QuoteLineItem(name: "Item", quantity: 1, unitPrice: 100)],
            discount: 250
        )
        #expect(quote.discountedSubtotal.value == 0)
        #expect(quote.total.value == 0)
    }

    @Test func taxAppliesAfterDiscount() {
        let quote = makeQuote(
            items: [QuoteLineItem(name: "Item", quantity: 2, unitPrice: 100)],
            discount: 50,
            taxRate: Decimal(string: "0.1")!
        )
        #expect(quote.discountedSubtotal.value == 150)
        #expect(quote.taxAmount.value == 15)
        #expect(quote.total.value == 165)
    }

    @Test func expiringSoonOnlyWhenAwaitingResponse() {
        var quote = makeQuote(items: [QuoteLineItem(name: "Item", quantity: 1, unitPrice: 10)])
        quote.expiresAt = LoopDate.adding(days: 2, to: Date())
        quote.status = .draft
        #expect(quote.expiresSoon == false)
        quote.status = .sent
        #expect(quote.expiresSoon)
        quote.expiresAt = LoopDate.adding(days: -1, to: Date())
        #expect(quote.isExpired)
    }

    @Test func emptyQuoteTotalsZero() {
        let quote = makeQuote(items: [])
        #expect(quote.subtotal.isZero)
        #expect(quote.total.isZero)
    }
}

// MARK: - Sales

struct SaleTests {

    private func makeSale(gross: Decimal, fees: Decimal, shipping: Decimal) -> SaleRecord {
        SaleRecord(
            id: UUID(), accountID: UUID(), ownedItemID: UUID(), itemName: "Item",
            platform: "eBay", grossAmount: .usd(gross), fees: .usd(fees),
            shippingCost: .usd(shipping), listedDate: nil, soldDate: nil,
            status: .listed, transactionID: nil, note: nil
        )
    }

    @Test func netProceedsSubtractCosts() {
        let sale = makeSale(gross: 260, fees: 18, shipping: 0)
        #expect(sale.netProceeds.value == 242)
        #expect(sale.totalCosts.value == 18)
    }

    @Test func netProceedsHandleFractionalCosts() {
        let sale = makeSale(gross: 185, fees: Decimal(string: "14.80")!, shipping: Decimal(string: "9.20")!)
        #expect(sale.netProceeds.value == 161)
    }

    @Test func timelineMarksSoldComplete() {
        var sale = makeSale(gross: 100, fees: 0, shipping: 0)
        sale.status = .sold
        #expect(sale.timeline.allSatisfy { $0.state == .complete })
    }
}

// MARK: - Return windows & refunds

struct ProtectionTests {

    @Test func returnWindowCountsRemainingDays() {
        let window = ReturnWindow(
            purchasedAt: LoopDate.adding(days: -26, to: Date()),
            policyDays: 30,
            policyNote: nil
        )
        #expect(window.daysRemaining == 4)
        #expect(window.isClosingSoon)
        #expect(!window.isExpired)
        #expect(window.state == .closingSoon)
    }

    @Test func expiredWindowReportsExpired() {
        let window = ReturnWindow(
            purchasedAt: LoopDate.adding(days: -60, to: Date()),
            policyDays: 30,
            policyNote: nil
        )
        #expect(window.isExpired)
        #expect(window.state == .expired)
    }

    @Test func extendedDeadlineOverridesPolicy() {
        let extended = LoopDate.adding(days: 20, to: Date())
        let window = ReturnWindow(
            purchasedAt: LoopDate.adding(days: -60, to: Date()),
            policyDays: 30,
            policyNote: nil,
            extendedDeadline: extended
        )
        #expect(!window.isExpired)
        #expect(window.daysRemaining == 20)
    }

    @Test func refundBecomesOverdueAfterFourteenDays() {
        var refund = Refund(
            id: UUID(), accountID: UUID(), merchant: "Nike", itemName: "Shoes",
            purchaseID: nil, returnRecordID: nil, expectedAmount: .usd(86.42),
            receivedAmount: nil, status: .pending, expectedDate: nil,
            receivedDate: nil, openedAt: LoopDate.adding(days: -15, to: Date()),
            transactionID: nil, note: nil
        )
        #expect(refund.isOverdue)
        refund.status = .received
        #expect(!refund.isOverdue)
    }

    @Test func refundOverdueWhenPastExpectedDate() {
        let refund = Refund(
            id: UUID(), accountID: UUID(), merchant: "Nike", itemName: "Shoes",
            purchaseID: nil, returnRecordID: nil, expectedAmount: .usd(10),
            receivedAmount: nil, status: .pending,
            expectedDate: LoopDate.adding(days: -5, to: Date()),
            receivedDate: nil, openedAt: LoopDate.adding(days: -6, to: Date()),
            transactionID: nil, note: nil
        )
        #expect(refund.isOverdue)
    }

    @Test func warrantyStatusFollowsCoverageEnd() {
        func warranty(endingIn days: Int?) -> Warranty {
            Warranty(
                id: UUID(), accountID: UUID(), ownedItemID: nil, itemName: "Item",
                provider: "Maker", kind: .manufacturer,
                coverageStart: LoopDate.adding(days: -100, to: Date()),
                coverageEnd: days.map { LoopDate.adding(days: $0, to: Date()) },
                referenceNumber: nil, documentIDs: [], note: nil
            )
        }
        #expect(warranty(endingIn: 300).status == .active)
        #expect(warranty(endingIn: 30).status == .expiring)
        #expect(warranty(endingIn: -1).status == .expired)
        #expect(warranty(endingIn: nil).status == .unknown)
    }

    @Test func returnTimelineTracksCurrentStage() {
        let record = ReturnRecord(
            id: UUID(), accountID: UUID(), purchaseID: UUID(), itemName: "Item",
            merchant: "Nike", status: .shipped, reason: nil, startedAt: Date(),
            deadline: nil, carrier: nil, trackingNumber: nil, shippedAt: Date(),
            merchantReceivedAt: nil, expectedRefund: .usd(20), refundID: nil,
            documentIDs: [], note: nil
        )
        let shipped = record.timeline.first { $0.id == ReturnStatus.shipped.rawValue }
        #expect(shipped?.state == .current)
        #expect(record.timeline.first?.state == .complete)
    }
}

// MARK: - Dates

struct LoopDateTests {

    @Test func deadlinePhrasing() {
        #expect(LoopDate.deadline(Date()) == "Due today")
        #expect(LoopDate.deadline(LoopDate.adding(days: 1, to: Date())) == "1 day left")
        #expect(LoopDate.deadline(LoopDate.adding(days: 4, to: Date())) == "4 days left")
        #expect(LoopDate.deadline(LoopDate.adding(days: -1, to: Date())) == "Expired yesterday")
    }

    @Test func relativePhrasing() {
        #expect(LoopDate.relative(Date()) == "Today")
        #expect(LoopDate.relative(LoopDate.adding(days: 1, to: Date())) == "Tomorrow")
        #expect(LoopDate.relative(LoopDate.adding(days: 3, to: Date())) == "in 3 days")
    }

    @Test func daysRemainingIgnoresTimeOfDay() {
        let tomorrowLate = LoopDate.adding(days: 1, to: Date()).addingTimeInterval(60 * 60 * 23)
        #expect(LoopDate.daysRemaining(until: tomorrowLate) == 1)
    }
}

// MARK: - Deep links

struct DeepLinkTests {

    private let identifier = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!

    @Test func parsesTabLinks() {
        #expect(DeepLinkRouter.parse(URL(string: "loop://today")!) == .tab(.today))
        #expect(DeepLinkRouter.parse(URL(string: "loop://money")!) == .tab(.money))
        #expect(DeepLinkRouter.parse(URL(string: "loop://ask")!) == .tab(.askLoop))
    }

    @Test func parsesRecordLinks() {
        let url = URL(string: "loop://refund/\(identifier.uuidString)")!
        #expect(DeepLinkRouter.parse(url) == .destination(.refund(identifier), tab: .money))

        let quote = URL(string: "loop://quote/\(identifier.uuidString)")!
        #expect(DeepLinkRouter.parse(quote) == .destination(.quote(identifier), tab: .business))
    }

    @Test func rejectsForeignSchemesAndBadIdentifiers() {
        #expect(DeepLinkRouter.parse(URL(string: "https://loop.app/today")!) == nil)
        #expect(DeepLinkRouter.parse(URL(string: "loop://refund/not-a-uuid")!) == nil)
        #expect(DeepLinkRouter.parse(URL(string: "loop://nowhere")!) == nil)
    }

    @Test func recognisesAuthCallback() {
        #expect(DeepLinkRouter.isAuthCallback(URL(string: "com.loop.app.loop_mobile://login-callback?code=abc")!))
        #expect(!DeepLinkRouter.isAuthCallback(URL(string: "loop://today")!))
    }

    @Test func actionSourceRoutesToOwningTab() {
        #expect(ActionSource.refund(identifier).owningTab == .money)
        #expect(ActionSource.sale(identifier).owningTab == .sell)
        #expect(ActionSource.lead(identifier).owningTab == .business)
    }
}

// MARK: - Today rules

struct TodayRuleTests {

    private var context: LoopContext { LoopFixtures.snapshot.context() }

    @Test func engineGeneratesActionsFromFixtureData() {
        let actions = TodayRuleEngine.standard.actions(from: context)
        #expect(!actions.isEmpty)
    }

    @Test func actionsAreSortedByPriorityThenDeadline() {
        let actions = TodayRuleEngine.standard.actions(from: context)
        let priorities = actions.map(\.priority.sortOrder)
        #expect(priorities == priorities.sorted())
    }

    @Test func returnDeadlineRuleFlagsClosingWindow() {
        let actions = ReturnDeadlineRule().generateActions(from: context)
        #expect(actions.contains { $0.subtitle?.contains("Sony WH-1000XM5") == true })
    }

    @Test func pendingRefundRuleFlagsOverdueRefund() {
        let actions = PendingRefundRule().generateActions(from: context)
        let nike = actions.first { $0.title.contains("Nike") }
        #expect(nike != nil)
        #expect(nike?.priority == .urgent)
    }

    @Test func missingReceiptRuleIgnoresPurchasesWithReceipts() {
        let actions = MissingReceiptRule().generateActions(from: context)
        #expect(!actions.contains { $0.title.contains("Sony WH-1000XM5") })
        #expect(actions.contains { $0.title.contains("Dyson") })
    }

    @Test func actionIdentitiesAreStableAcrossRuns() {
        let first = TodayRuleEngine.standard.actions(from: context).map(\.id)
        let second = TodayRuleEngine.standard.actions(from: context).map(\.id)
        #expect(first == second)
    }

    @Test func completedActionsMoveOutOfOpenSections() {
        let engine = TodayRuleEngine.standard
        let actions = engine.actions(from: context)
        guard let first = actions.first else { return }
        let digest = engine.digest(from: context, completedActionIDs: [first.id: Date()])
        #expect(digest.recentlyCompleted.contains { $0.id == first.id })
        #expect(!digest.needsAttention.contains { $0.id == first.id })
    }

    @Test func digestSummarisesMoneyAtStake() {
        let digest = TodayRuleEngine.standard.digest(from: context, completedActionIDs: [:])
        #expect(digest.moneyAtStake.value == Decimal(string: "86.42"))
    }
}

// MARK: - Sample store behaviour (cross-feature flows)

@MainActor
struct SampleStoreFlowTests {

    @Test func settlingRefundClearsLedgerAndCountsRecovered() throws {
        let store = SampleDataStore()
        let refund = try #require(store.snapshot.refunds.first { $0.status == .pending })
        _ = try store.markRefundReceived(id: refund.id, amount: refund.expectedAmount)

        let updated = try #require(store.snapshot.refunds.first { $0.id == refund.id })
        #expect(updated.status == .received)

        let transaction = store.snapshot.transactions.first { $0.id == refund.transactionID }
        #expect(transaction?.status == .cleared)
    }

    @Test func completingSaleWritesNetProceedsToMoney() throws {
        let store = SampleDataStore()
        let sale = try #require(store.snapshot.sales.first { $0.status == .pending })
        let completed = try store.markSold(saleID: sale.id)

        #expect(completed.status == .sold)
        let transaction = store.snapshot.transactions.first { $0.id == completed.transactionID }
        #expect(transaction?.amount.value == completed.netProceeds.value)
        #expect(transaction?.type == .resale)
    }

    @Test func recordingEarningCreatesSingleLedgerEntry() {
        let store = SampleDataStore()
        let before = store.snapshot.transactions.count
        let earning = BusinessEarning(
            id: UUID(), accountID: store.profile.activeAccountID, title: "Test job",
            customerID: nil, opportunityID: nil, quoteID: nil, amount: .usd(825),
            receivedAt: Date(), source: .manual, transactionID: nil, note: nil
        )
        let saved = store.recordEarning(earning)
        #expect(store.snapshot.transactions.count == before + 1)
        #expect(saved.transactionID != nil)
    }

    @Test func convertingLeadCreatesLinkedOpportunity() throws {
        let store = SampleDataStore()
        let lead = try #require(store.snapshot.leads.first { $0.status == .qualified && $0.opportunityID == nil }
            ?? store.snapshot.leads.first { $0.status == .new })
        let opportunity = try store.convertLead(id: lead.id)

        let updatedLead = try #require(store.snapshot.leads.first { $0.id == lead.id })
        #expect(updatedLead.status == .converted)
        #expect(updatedLead.opportunityID == opportunity.id)
        #expect(opportunity.leadID == lead.id)
    }

    @Test func acceptingQuoteWinsItsOpportunity() throws {
        let store = SampleDataStore()
        let quote = try #require(store.snapshot.quotes.first { $0.opportunityID != nil })
        _ = try store.setQuoteStatus(id: quote.id, status: .accepted)

        let opportunity = store.snapshot.opportunities.first { $0.id == quote.opportunityID }
        #expect(opportunity?.stage == .won)
    }

    @Test func advancingReturnToRefundPendingOpensRefund() throws {
        let store = SampleDataStore()
        let purchase = try #require(store.snapshot.purchases.first { $0.itemName.contains("Dyson") })
        let record = try store.startReturn(purchaseID: purchase.id, reason: "Testing")
        let advanced = try store.advanceReturn(id: record.id, to: .refundPending)

        #expect(advanced.refundID != nil)
        let refund = store.snapshot.refunds.first { $0.id == advanced.refundID }
        #expect(refund?.status == .pending)
        #expect(refund?.expectedAmount.value == purchase.amount.value)
    }

    @Test func searchFindsRecordsAcrossModules() {
        let store = SampleDataStore()
        #expect(!store.search(query: "Sony", category: .all).isEmpty)
        #expect(!store.search(query: "Johnson", category: .business).isEmpty)
        #expect(store.search(query: "zzzzz", category: .all).isEmpty)
    }

    @Test func moneySummaryNeverMixesPendingIntoCleared() {
        let store = SampleDataStore()
        let summary = store.moneySummary()
        #expect(summary.pendingIncoming.value >= 0)
        #expect(summary.netMovement.value == summary.incoming.value - summary.outgoing.value)
    }
}

// MARK: - Errors

struct LoopErrorTests {

    @Test func mapsURLErrorsToSafeCases() {
        let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        #expect(LoopError.map(offline) == .offline)

        let cancelled = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        #expect(LoopError.map(cancelled) == .cancelled)
    }

    @Test func messagesNeverLeakInternals() {
        let error = LoopError.server(message: "LOOP's server had a problem. Please try again.")
        #expect(!error.message.lowercased().contains("select"))
        #expect(!error.message.lowercased().contains("token"))
    }

    @Test func retryabilityMatchesCase() {
        #expect(LoopError.network.isRetryable)
        #expect(!LoopError.forbidden.isRetryable)
        #expect(!LoopError.cancelled.isRetryable)
    }
}

// MARK: - Production backend contract

struct ProductionBackendContractTests {

    @Test func productionSupabaseProjectIsLoop() {
        #expect(LoopConfiguration.supabaseURL?.absoluteString == "https://zqalnvfwxmfrnyjcuehq.supabase.co")
        #expect(LoopConfiguration.supabaseAnonKey.hasPrefix("sb_publishable_"))
    }

    @Test func oauthCallbackMatchesExistingLoopMobileContract() {
        #expect(LoopConfiguration.oauthRedirectURL.absoluteString == "com.loop.app.loop_mobile://login-callback")
        #expect(LoopConfiguration.oauthURLScheme == "com.loop.app.loop_mobile")
        #expect(DeepLinkRouter.isAuthCallback(LoopConfiguration.oauthRedirectURL))
    }

    @Test func oauthCallbackRejectsOrdinaryLoopDeepLinks() {
        let ordinary = URL(string: "loop://today")!
        #expect(!DeepLinkRouter.isAuthCallback(ordinary))
        #expect(DeepLinkRouter.parse(ordinary) == .tab(.today))
    }

    @Test func wrongOauthHostIsRejected() {
        let wrong = URL(string: "com.loop.app.loop_mobile://auth-callback")!
        #expect(!DeepLinkRouter.isAuthCallback(wrong))
    }

    @Test func askLoopUsesDeployedServerApi() {
        #expect(LoopConfiguration.apiBaseURL?.absoluteString == "https://loop-teal-rho.vercel.app/api")
    }
}
