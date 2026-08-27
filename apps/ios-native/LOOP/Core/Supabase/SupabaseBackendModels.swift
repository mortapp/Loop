import Foundation

/// Exact row shapes for LOOP's production Supabase schema. These types are kept
/// separate from the SwiftUI domain models so backend column names can evolve
/// without teaching views about PostgREST.
nonisolated enum SupabaseBackend {
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let iso8601Fractional = ISO8601DateFormatter()

    static func date(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if value.count == 10 { return dateOnly.date(from: value) }
        if let date = iso8601Fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }

    static func cents(_ value: Int64?, currency: String = "USD") -> MoneyAmount {
        MoneyAmount(Decimal(value ?? 0) / 100, currencyCode: currency)
    }

    static func intCents(_ value: MoneyAmount) throws -> Int64 {
        let rounded = MoneyFormatter.rounded(value.value, scale: 2)
        guard rounded == value.value else {
            throw LoopError.validation("Amounts must use no more than two decimal places.")
        }
        var scaled = rounded * 100
        var integral = Decimal()
        NSDecimalRound(&integral, &scaled, 0, .plain)
        guard integral == scaled,
              let result = Int64(NSDecimalNumber(decimal: integral).stringValue) else {
            throw LoopError.validation("Enter a valid amount.")
        }
        return result
    }

    struct ProfileRow: Decodable, Sendable {
        let id: UUID
        let email: String
        let displayName: String?
        let avatarUrl: String?
        let defaultMode: String
        let createdAt: String
        let username: String?
    }

    struct AccountRow: Decodable, Sendable {
        let id: UUID
        let type: String
        let ownerProfileId: UUID?
        let businessId: UUID?
        let createdAt: String
    }

    struct BusinessRow: Decodable, Sendable {
        let id: UUID
        let name: String
    }

    struct MoneyEventRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let itemId: UUID?
        let kind: String
        let amountCents: Int64
        let currency: String
        let occurredAt: String
        let sourceType: String?
        let sourceId: UUID?
        let description: String?
    }

    struct MoneyTotalsRow: Decodable, Sendable {
        let madeCents: Int64
        let protectedCents: Int64
        let recoveredCents: Int64
        let spentCents: Int64
        let feesCents: Int64
        let netCents: Int64
    }

    struct ItemRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let name: String
        let description: String?
        let category: String?
        let condition: String?
        let brand: String?
        let model: String?
        let purchasePriceCents: Int64?
        let purchaseDate: String?
        let status: String
        let createdAt: String
    }

    struct PurchaseRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let itemId: UUID?
        let vendorName: String?
        let purchaseDate: String?
        let priceCents: Int64?
        let receiptDocumentId: UUID?
        let warrantyExpiresAt: String?
        let returnWindowExpiresAt: String?
        let createdAt: String
    }

    struct ReturnRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let itemId: UUID
        let purchaseId: UUID?
        let reason: String?
        let status: String
        let refundAmountCents: Int64?
        let initiatedAt: String
        let resolvedAt: String?
        let createdAt: String
    }

    struct WarrantyRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let itemId: UUID
        let provider: String?
        let coverageSummary: String?
        let startsAt: String?
        let expiresAt: String?
        let claimStatus: String?
        let createdAt: String
    }

    struct DocumentRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let itemId: UUID?
        let kind: String
        let relatedType: String?
        let relatedId: UUID?
        let storagePath: String
        let fileName: String
        let mimeType: String?
        let sizeBytes: Int64?
        let createdAt: String
    }

    struct ListingRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let itemId: UUID
        let marketplace: String
        let status: String
        let listPriceCents: Int64?
        let listingUrl: String?
        let publishedAt: String?
        let createdAt: String
    }

    struct SaleRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let itemId: UUID
        let listingId: UUID?
        let salePriceCents: Int64
        let feesCents: Int64
        let netAmountCents: Int64
        let soldAt: String
        let createdAt: String
    }

    struct ValuationRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let itemId: UUID
        let source: String
        let estimatedValueCents: Int64
        let confidence: Decimal?
        let valuedAt: String
    }

    struct ContactRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let displayName: String
        let email: String?
        let phone: String?
        let company: String?
        let notes: String?
        let createdAt: String
    }

    struct LeadRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let contactId: UUID?
        let source: String?
        let status: String
        let notes: String?
        let createdAt: String
    }

    struct OpportunityRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let contactId: UUID?
        let leadId: UUID?
        let title: String
        let stage: String
        let estimatedValueCents: Int64?
        let createdAt: String
    }

    struct QuoteRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let opportunityId: UUID?
        let contactId: UUID?
        let quoteNumber: String
        let status: String
        let subtotalCents: Int64
        let taxCents: Int64
        let totalCents: Int64
        let currency: String
        let validUntil: String?
        let sentAt: String?
        let acceptedAt: String?
        let createdAt: String
    }

    struct QuoteLineRow: Decodable, Sendable {
        let id: UUID
        let quoteId: UUID
        let description: String
        let quantity: Decimal
        let unitPriceCents: Int64
        let position: Int
    }

    struct ActionRow: Decodable, Sendable {
        let id: UUID
        let accountId: UUID
        let type: String
        let title: String
        let description: String?
        let status: String
        let dueAt: String?
        let relatedType: String?
        let relatedId: UUID?
        let createdAt: String
        let completedAt: String?
    }
}
