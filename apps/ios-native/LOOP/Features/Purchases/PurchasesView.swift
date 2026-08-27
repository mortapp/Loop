import SwiftUI

nonisolated enum PurchaseFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case returnable
    case closingSoon
    case missingReceipt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .returnable: return "Returnable"
        case .closingSoon: return "Closing soon"
        case .missingReceipt: return "No receipt"
        }
    }
}

/// Every purchase LOOP knows about — the junction into Protect and Sell.
struct PurchasesView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[Purchase]> = .idle
    @State private var documents: [LoopDocument] = []
    @State private var filter: PurchaseFilter = .all
    @State private var query: String = ""

    private var visiblePurchases: [Purchase] {
        let all = state.value ?? []
        let receiptTargets = Set(documents.filter { $0.type == .receipt }.map(\.target.id))
        return all.filter { purchase in
            let matchesQuery = query.isEmpty
                || purchase.itemName.localizedStandardContains(query)
                || purchase.merchant.localizedStandardContains(query)
            guard matchesQuery else { return false }
            switch filter {
            case .all:
                return true
            case .returnable:
                return purchase.returnWindow?.isExpired == false
            case .closingSoon:
                return purchase.returnWindow?.isClosingSoon == true
            case .missingReceipt:
                return !receiptTargets.contains(DocumentAttachmentTarget.purchase(purchase.id).id)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                LoopFilterChips(values: PurchaseFilter.allCases, selection: $filter) { $0.label }
                    .padding(.horizontal, -LoopSpacing.gutter)

                LoadableView(state: state, loadingRows: 5, retry: { Task { await load() } }) { _ in
                    if visiblePurchases.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "bag",
                                title: query.isEmpty ? "No purchases yet" : "No matches",
                                message: query.isEmpty
                                    ? "Purchases carry their receipt, return window and warranty. Add one and LOOP will watch every deadline for you."
                                    : "Nothing matches “\(query)”. Try another item or merchant."
                            )
                        }
                    } else {
                        VStack(spacing: LoopSpacing.md) {
                            ForEach(visiblePurchases) { purchase in
                                PurchaseCard(
                                    purchase: purchase,
                                    hasReceipt: hasReceipt(purchase)
                                ) {
                                    router.push(.purchase(purchase.id))
                                }
                            }
                        }
                    }
                }
            }
            .loopGutter()
            .padding(.vertical, LoopSpacing.md)
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("Purchases")
        .searchable(text: $query, prompt: "Item or merchant")
        .task { await load() }
        .refreshable { await load() }
    }

    private func hasReceipt(_ purchase: Purchase) -> Bool {
        documents.contains { $0.type == .receipt && $0.target == .purchase(purchase.id) }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            async let purchases = loop.purchaseService.purchases(accountID: accountID)
            async let docs = loop.documentService.documents(accountID: accountID)
            let (loadedPurchases, loadedDocs) = try await (purchases, docs)
            documents = loadedDocs
            state = .loaded(loadedPurchases)
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct PurchaseCard: View {
    let purchase: Purchase
    let hasReceipt: Bool
    let action: () -> Void

    var body: some View {
        LoopCardButton(action: action) {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                HStack(alignment: .top, spacing: LoopSpacing.md) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(purchase.itemName)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(LoopColor.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(purchase.merchant) · \(LoopDate.medium(purchase.purchasedAt))")
                            .font(LoopFont.footnote)
                            .foregroundStyle(LoopColor.inkSecondary)
                    }
                    Spacer(minLength: LoopSpacing.sm)
                    LoopMoneyText(amount: purchase.amount, size: 17)
                }

                HStack(spacing: LoopSpacing.sm) {
                    if let window = purchase.returnWindow {
                        LoopStatusBadge(
                            title: window.isExpired ? window.state.label : LoopDate.deadline(window.deadline),
                            tone: window.state.tone,
                            symbol: window.isExpired ? "clock.badge.xmark" : "arrow.uturn.backward"
                        )
                    }
                    LoopStatusBadge(
                        title: hasReceipt ? "Receipt" : "No receipt",
                        tone: hasReceipt ? .neutral : .caution,
                        symbol: hasReceipt ? "checkmark" : "exclamationmark"
                    )
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
