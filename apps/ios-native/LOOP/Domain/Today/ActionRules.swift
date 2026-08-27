import Foundation

/// A pure rule that derives Today actions from LOOP data.
nonisolated protocol ActionRule: Sendable {
    var identifier: String { get }
    func generateActions(from context: LoopContext) -> [LoopAction]
}

extension ActionRule {
    func makeAction(
        key: String,
        context: LoopContext,
        type: LoopActionType,
        title: String,
        subtitle: String?,
        priority: ActionPriority,
        dueDate: Date? = nil,
        amount: MoneyAmount? = nil,
        source: ActionSource
    ) -> LoopAction {
        LoopAction(
            id: .deterministic(from: "\(identifier)|\(key)"),
            accountID: context.accountID,
            type: type,
            title: title,
            subtitle: subtitle,
            priority: priority,
            dueDate: dueDate,
            amount: amount,
            source: source,
            createdAt: context.now,
            completedAt: nil
        )
    }
}

// MARK: - Return deadlines

nonisolated struct ReturnDeadlineRule: ActionRule {
    let identifier = "return-deadline"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.purchases.compactMap { purchase in
            guard let window = purchase.returnWindow, !window.isExpired else { return nil }
            guard window.daysRemaining <= 10 else { return nil }
            let alreadyReturning = context.returns.contains {
                $0.purchaseID == purchase.id && $0.status.isOpen
            }
            guard !alreadyReturning else { return nil }
            let priority: ActionPriority = window.daysRemaining <= 2 ? .urgent : .high
            return makeAction(
                key: purchase.id.uuidString,
                context: context,
                type: .returnWindowClosing,
                title: window.daysRemaining == 0
                    ? "Return window closes today"
                    : "Return window closes in \(window.daysRemaining) day\(window.daysRemaining == 1 ? "" : "s")",
                subtitle: "\(purchase.itemName) · \(purchase.merchant)",
                priority: priority,
                dueDate: window.deadline,
                amount: purchase.amount,
                source: .purchase(purchase.id)
            )
        }
    }
}

// MARK: - Refunds

nonisolated struct PendingRefundRule: ActionRule {
    let identifier = "refund-pending"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.refunds.compactMap { refund in
            guard refund.status.isOutstanding else { return nil }
            let overdue = refund.isOverdue
            return makeAction(
                key: refund.id.uuidString,
                context: context,
                type: overdue ? .refundOverdue : .refundPending,
                title: overdue
                    ? "\(refund.merchant) refund is overdue"
                    : "\(refund.merchant) refund still pending",
                subtitle: LoopDate.ageDescription(since: refund.openedAt, noun: "Waiting")
                    + " · \(refund.itemName)",
                priority: overdue ? .urgent : .high,
                dueDate: refund.expectedDate,
                amount: refund.expectedAmount,
                source: .refund(refund.id)
            )
        }
    }
}

nonisolated struct RefundReceivedRule: ActionRule {
    let identifier = "refund-received"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.refunds.compactMap { refund in
            guard refund.status == .received,
                  let received = refund.receivedDate,
                  LoopDate.daysElapsed(since: received) <= 7 else { return nil }
            return makeAction(
                key: refund.id.uuidString,
                context: context,
                type: .refundReceived,
                title: "Refund recovered from \(refund.merchant)",
                subtitle: "\(refund.itemName) · \(LoopDate.relative(received))",
                priority: .informational,
                amount: refund.settledAmount,
                source: .refund(refund.id)
            )
        }
    }
}

// MARK: - Receipts

nonisolated struct MissingReceiptRule: ActionRule {
    let identifier = "missing-receipt"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.purchases.compactMap { purchase in
            guard !context.hasReceipt(purchaseID: purchase.id) else { return nil }
            guard let window = purchase.returnWindow, !window.isExpired else { return nil }
            return makeAction(
                key: purchase.id.uuidString,
                context: context,
                type: .receiptMissing,
                title: "Add a receipt for \(purchase.itemName)",
                subtitle: "Protects your return and warranty at \(purchase.merchant)",
                priority: window.daysRemaining <= 7 ? .high : .normal,
                dueDate: window.deadline,
                amount: purchase.amount,
                source: .purchase(purchase.id)
            )
        }
    }
}

// MARK: - Warranties

nonisolated struct WarrantyExpiryRule: ActionRule {
    let identifier = "warranty-expiring"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.warranties.compactMap { warranty in
            guard warranty.status == .expiring, let days = warranty.daysRemaining else { return nil }
            return makeAction(
                key: warranty.id.uuidString,
                context: context,
                type: .warrantyExpiring,
                title: "Warranty ends in \(days) days",
                subtitle: "\(warranty.itemName) · \(warranty.provider)",
                priority: days <= 14 ? .high : .informational,
                dueDate: warranty.coverageEnd,
                source: .warranty(warranty.id)
            )
        }
    }
}

// MARK: - Resale

nonisolated struct ResaleOpportunityRule: ActionRule {
    let identifier = "resale-opportunity"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.ownedItems.compactMap { item in
            guard !item.isSold, item.isMarkedForSale == false else { return nil }
            guard item.ageInDays >= 180, let estimate = item.estimatedResaleValue else { return nil }
            let hasSale = context.sales.contains { $0.ownedItemID == item.id && $0.status != .cancelled }
            guard !hasSale else { return nil }
            return makeAction(
                key: item.id.uuidString,
                context: context,
                type: .resaleOpportunity,
                title: "\(item.name) could be worth selling",
                subtitle: item.estimateIsUserProvided
                    ? "Your estimate · owned \(item.ageInDays) days"
                    : "Estimate only · owned \(item.ageInDays) days",
                priority: .normal,
                amount: estimate,
                source: .ownedItem(item.id)
            )
        }
    }
}

nonisolated struct SaleFollowUpRule: ActionRule {
    let identifier = "sale-followup"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.sales.compactMap { sale in
            switch sale.status {
            case .listed:
                guard let listed = sale.listedDate, LoopDate.daysElapsed(since: listed) >= 21 else { return nil }
                return makeAction(
                    key: sale.id.uuidString,
                    context: context,
                    type: .saleFollowUp,
                    title: "\(sale.itemName) has been listed a while",
                    subtitle: LoopDate.ageDescription(since: listed, noun: "Listed for"),
                    priority: .normal,
                    amount: sale.grossAmount,
                    source: .sale(sale.id)
                )
            case .pending:
                return makeAction(
                    key: sale.id.uuidString,
                    context: context,
                    type: .saleFollowUp,
                    title: "Finish the sale of \(sale.itemName)",
                    subtitle: "Buyer committed · confirm payment to record proceeds",
                    priority: .high,
                    amount: sale.netProceeds,
                    source: .sale(sale.id)
                )
            default:
                return nil
            }
        }
    }
}

// MARK: - Business

nonisolated struct LeadFollowUpRule: ActionRule {
    let identifier = "lead-followup"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.leads.compactMap { lead in
            guard !lead.isArchived, lead.status.isOpen, let followUp = lead.nextFollowUp else { return nil }
            let days = LoopDate.daysRemaining(until: followUp)
            guard days <= 2 else { return nil }
            return makeAction(
                key: lead.id.uuidString,
                context: context,
                type: .leadFollowUp,
                title: days < 0
                    ? "Follow-up overdue: \(lead.name)"
                    : "Follow up with \(lead.name)",
                subtitle: "\(lead.status.label) lead · \(LoopDate.relative(followUp))",
                priority: days < 0 ? .urgent : .high,
                dueDate: followUp,
                amount: lead.estimatedValue,
                source: .lead(lead.id)
            )
        }
    }
}

nonisolated struct QuoteFollowUpRule: ActionRule {
    let identifier = "quote-followup"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.quotes.compactMap { quote in
            guard !quote.isArchived, quote.status.isAwaitingResponse else { return nil }
            if quote.expiresSoon, let expiry = quote.expiresAt {
                return makeAction(
                    key: "expiring-\(quote.id.uuidString)",
                    context: context,
                    type: .quoteExpiringSoon,
                    title: "Quote \(quote.reference) expires \(LoopDate.relative(expiry).lowercased())",
                    subtitle: quote.title,
                    priority: .urgent,
                    dueDate: expiry,
                    amount: quote.total,
                    source: .quote(quote.id)
                )
            }
            let waiting = LoopDate.daysElapsed(since: quote.issuedAt)
            guard waiting >= 4 else { return nil }
            return makeAction(
                key: "waiting-\(quote.id.uuidString)",
                context: context,
                type: .quoteAwaitingResponse,
                title: "\(quote.reference) is awaiting a response",
                subtitle: "\(quote.title) · \(LoopDate.ageDescription(since: quote.issuedAt, noun: "Sent"))ago",
                priority: .normal,
                dueDate: quote.expiresAt,
                amount: quote.total,
                source: .quote(quote.id)
            )
        }
    }
}

nonisolated struct OpportunityAttentionRule: ActionRule {
    let identifier = "opportunity-attention"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.opportunities.compactMap { opportunity in
            guard !opportunity.isArchived, opportunity.needsAttention,
                  let close = opportunity.expectedCloseDate else { return nil }
            return makeAction(
                key: opportunity.id.uuidString,
                context: context,
                type: .opportunityNeedsAttention,
                title: "\(opportunity.title) closes \(LoopDate.relative(close).lowercased())",
                subtitle: "\(opportunity.stage.label) · move it forward",
                priority: .high,
                dueDate: close,
                amount: opportunity.estimatedValue,
                source: .opportunity(opportunity.id)
            )
        }
    }
}

nonisolated struct EarningsRecordedRule: ActionRule {
    let identifier = "earnings-recorded"

    func generateActions(from context: LoopContext) -> [LoopAction] {
        context.earnings.compactMap { earning in
            guard LoopDate.daysElapsed(since: earning.receivedAt) <= 7 else { return nil }
            return makeAction(
                key: earning.id.uuidString,
                context: context,
                type: .earningsRecorded,
                title: "Business income recorded",
                subtitle: "\(earning.title) · \(LoopDate.relative(earning.receivedAt))",
                priority: .informational,
                amount: earning.amount,
                source: earning.transactionID.map { ActionSource.transaction($0) }
                    ?? .opportunity(earning.opportunityID ?? earning.id)
            )
        }
    }
}

// MARK: - Engine

/// Runs every rule and assembles the grouped Today digest.
nonisolated struct TodayRuleEngine: Sendable {
    let rules: [any ActionRule]

    static let standard = TodayRuleEngine(rules: [
        ReturnDeadlineRule(),
        PendingRefundRule(),
        RefundReceivedRule(),
        MissingReceiptRule(),
        WarrantyExpiryRule(),
        ResaleOpportunityRule(),
        SaleFollowUpRule(),
        LeadFollowUpRule(),
        QuoteFollowUpRule(),
        OpportunityAttentionRule(),
        EarningsRecordedRule()
    ])

    func actions(from context: LoopContext) -> [LoopAction] {
        rules
            .flatMap { $0.generateActions(from: context) }
            .sorted { lhs, rhs in
                let left = lhs.sortKey
                let right = rhs.sortKey
                if left.0 != right.0 { return left.0 < right.0 }
                return left.1 < right.1
            }
    }

    /// Builds the grouped digest, applying locally completed action IDs.
    func digest(
        from context: LoopContext,
        completedActionIDs: [UUID: Date]
    ) -> TodayDigest {
        let generated = actions(from: context).map { action -> LoopAction in
            var action = action
            action.completedAt = completedActionIDs[action.id]
            return action
        }
        let open = generated.filter { !$0.isCompleted }
        let completed = generated.filter(\.isCompleted)

        let atStake = MoneyAmount.sum(
            context.refunds.filter { $0.status.isOutstanding }.map(\.expectedAmount)
        )
        let monthStart = LoopDate.calendar.date(
            from: LoopDate.calendar.dateComponents([.year, .month], from: context.now)
        ) ?? context.now
        let recovered = MoneyAmount.sum(
            context.refunds
                .filter { $0.status == .received && ($0.receivedDate ?? .distantPast) >= monthStart }
                .map(\.settledAmount)
        )

        return TodayDigest(
            date: context.now,
            needsAttention: open.filter { $0.priority == .urgent },
            dueSoon: open.filter { $0.priority == .high },
            opportunities: open.filter { $0.priority == .normal },
            information: open.filter { $0.priority == .informational },
            recentlyCompleted: completed.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) },
            moneyAtStake: atStake,
            recoveredThisMonth: recovered
        )
    }
}
