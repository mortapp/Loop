import Foundation

/// A read-only snapshot of everything in an account, handed to the Today rules.
/// Rules are pure functions of this context, so they can later be replaced by
/// server-generated actions without touching the UI.
nonisolated struct LoopContext: Sendable {
    let accountID: UUID
    let now: Date
    var purchases: [Purchase]
    var ownedItems: [OwnedItem]
    var returns: [ReturnRecord]
    var refunds: [Refund]
    var warranties: [Warranty]
    var documents: [LoopDocument]
    var sales: [SaleRecord]
    var leads: [Lead]
    var opportunities: [Opportunity]
    var quotes: [Quote]
    var earnings: [BusinessEarning]
    var transactions: [MoneyTransaction]

    func hasReceipt(purchaseID: UUID) -> Bool {
        documents.contains { document in
            document.type == .receipt && document.target == .purchase(purchaseID)
        }
    }

    func customerName(for id: UUID?, in customers: [Customer]) -> String? {
        guard let id else { return nil }
        return customers.first(where: { $0.id == id })?.displayName
    }
}

extension UUID {
    /// Stable UUID derived from a string key, so generated actions keep the same
    /// identity across refreshes (which makes completion and animation reliable).
    static func deterministic(from key: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in Array(key.utf8) {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
            bytes[Int(hash % 16)] = bytes[Int(hash % 16)] ^ byte
        }
        var mixed = hash
        for index in 0..<8 {
            bytes[index] = bytes[index] ^ UInt8(truncatingIfNeeded: mixed)
            mixed >>= 8
        }
        var second = hash &* 0x9E3779B97F4A7C15
        for index in 8..<16 {
            bytes[index] = bytes[index] ^ UInt8(truncatingIfNeeded: second)
            second >>= 8
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let tuple = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }
}
