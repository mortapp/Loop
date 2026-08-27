import Foundation

/// A complete, in-memory picture of one LOOP account.
/// Both the sample environment and any future local cache use this shape.
nonisolated struct LoopDataSnapshot: Sendable {
    var profile: LoopProfile
    var purchases: [Purchase] = []
    var ownedItems: [OwnedItem] = []
    var returns: [ReturnRecord] = []
    var refunds: [Refund] = []
    var warranties: [Warranty] = []
    var documents: [LoopDocument] = []
    var sales: [SaleRecord] = []
    var customers: [Customer] = []
    var leads: [Lead] = []
    var opportunities: [Opportunity] = []
    var quotes: [Quote] = []
    var earnings: [BusinessEarning] = []
    var transactions: [MoneyTransaction] = []
    var completedActionIDs: [UUID: Date] = [:]

    func context(now: Date = Date()) -> LoopContext {
        LoopContext(
            accountID: profile.activeAccountID,
            now: now,
            purchases: purchases,
            ownedItems: ownedItems,
            returns: returns,
            refunds: refunds,
            warranties: warranties,
            documents: documents,
            sales: sales,
            leads: leads,
            opportunities: opportunities,
            quotes: quotes,
            earnings: earnings,
            transactions: transactions
        )
    }
}
