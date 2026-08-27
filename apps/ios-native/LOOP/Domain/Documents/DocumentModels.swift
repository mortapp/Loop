import Foundation

nonisolated enum DocumentType: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case receipt
    case invoice
    case warranty
    case returnConfirmation
    case shippingEvidence
    case refundConfirmation
    case quote
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .receipt: return "Receipt"
        case .invoice: return "Invoice"
        case .warranty: return "Warranty"
        case .returnConfirmation: return "Return confirmation"
        case .shippingEvidence: return "Shipping evidence"
        case .refundConfirmation: return "Refund confirmation"
        case .quote: return "Quote"
        case .other: return "Document"
        }
    }

    var symbolName: String {
        switch self {
        case .receipt: return "receipt"
        case .invoice: return "doc.text"
        case .warranty: return "shield.lefthalf.filled"
        case .returnConfirmation: return "arrow.uturn.backward.square"
        case .shippingEvidence: return "shippingbox"
        case .refundConfirmation: return "checkmark.seal"
        case .quote: return "doc.plaintext"
        case .other: return "paperclip"
        }
    }
}

/// What a document is attached to.
nonisolated enum DocumentAttachmentTarget: Codable, Hashable, Sendable, Identifiable {
    case purchase(UUID)
    case returnRecord(UUID)
    case refund(UUID)
    case warranty(UUID)
    case sale(UUID)
    case quote(UUID)

    var id: String {
        switch self {
        case .purchase(let id): return "purchase-\(id.uuidString)"
        case .returnRecord(let id): return "return-\(id.uuidString)"
        case .refund(let id): return "refund-\(id.uuidString)"
        case .warranty(let id): return "warranty-\(id.uuidString)"
        case .sale(let id): return "sale-\(id.uuidString)"
        case .quote(let id): return "quote-\(id.uuidString)"
        }
    }

    var label: String {
        switch self {
        case .purchase: return "Purchase"
        case .returnRecord: return "Return"
        case .refund: return "Refund"
        case .warranty: return "Warranty"
        case .sale: return "Sale"
        case .quote: return "Quote"
        }
    }
}

/// Storage-agnostic document metadata. The remote URL is resolved by the
/// document service so SwiftUI is never coupled to one storage provider.
nonisolated struct LoopDocument: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accountID: UUID
    var type: DocumentType
    var filename: String
    var byteSize: Int?
    var createdAt: Date
    var target: DocumentAttachmentTarget
    var storagePath: String?
    var note: String?

    var sizeDescription: String? {
        guard let byteSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file)
    }
}
