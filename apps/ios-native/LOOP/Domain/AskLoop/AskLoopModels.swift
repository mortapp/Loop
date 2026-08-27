import Foundation

nonisolated enum AskLoopRole: String, Codable, Hashable, Sendable {
    case user
    case loop
}

nonisolated struct AskLoopMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    var role: AskLoopRole
    var text: String
    var createdAt: Date
    var referencedDestinations: [AskLoopReference]
    var deliveryState: DeliveryState

    nonisolated enum DeliveryState: Hashable, Sendable {
        case sending
        case delivered
        case failed(LoopError)
    }

    init(
        id: UUID = UUID(),
        role: AskLoopRole,
        text: String,
        createdAt: Date = Date(),
        referencedDestinations: [AskLoopReference] = [],
        deliveryState: DeliveryState = .delivered
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.referencedDestinations = referencedDestinations
        self.deliveryState = deliveryState
    }
}

/// A record Ask LOOP pointed at, rendered as a tappable chip under the answer.
nonisolated struct AskLoopReference: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var label: String
    var source: ActionSource

    init(id: UUID = UUID(), label: String, source: ActionSource) {
        self.id = id
        self.label = label
        self.source = source
    }
}

nonisolated struct AskLoopResponse: Codable, Hashable, Sendable {
    var text: String
    var references: [AskLoopReference]
    /// True when the answer came from LOOP's live intelligence service.
    var isLiveIntelligence: Bool
}

nonisolated struct AskLoopSuggestion: Identifiable, Hashable, Sendable {
    let id: String
    let text: String
    let symbolName: String

    static let starters: [AskLoopSuggestion] = [
        .init(id: "attention", text: "What needs my attention today?", symbolName: "bell.badge"),
        .init(id: "returns", text: "Which returns expire soon?", symbolName: "arrow.uturn.backward"),
        .init(id: "recovered", text: "How much money did I recover?", symbolName: "arrow.down.left.circle"),
        .init(id: "sell", text: "What can I sell?", symbolName: "tag"),
        .init(id: "leads", text: "Which leads need follow-up?", symbolName: "person.crop.circle.badge.clock"),
        .init(id: "quotes", text: "Which quotes are waiting?", symbolName: "doc.plaintext"),
        .init(id: "summary", text: "Summarize my recent LOOP activity.", symbolName: "sparkle")
    ]
}
