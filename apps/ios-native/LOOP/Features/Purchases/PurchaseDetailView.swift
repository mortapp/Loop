import SwiftUI

/// The full ownership lifecycle of one purchase.
struct PurchaseDetailView: View {
    let purchaseID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<Payload> = .idle

    nonisolated struct Payload: Sendable {
        var purchase: Purchase
        var documents: [LoopDocument]
        var returnRecord: ReturnRecord?
        var refund: Refund?
        var warranty: Warranty?
        var ownedItem: OwnedItem?
    }

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { payload in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    header(payload.purchase)
                    lifecycle(payload)
                    details(payload.purchase)
                    receiptSection(payload)
                    if let note = payload.purchase.note {
                        LoopDetailSection(title: "Note") {
                            Text(note)
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    actions(payload)
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Purchase")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Sections

    private func header(_ purchase: Purchase) -> some View {
        LoopCard(padding: LoopSpacing.xl, isRaised: true) {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                Text(purchase.itemName)
                    .font(LoopFont.display(24, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(purchase.merchant) · \(LoopDate.medium(purchase.purchasedAt))")
                    .font(LoopFont.subheadline)
                    .foregroundStyle(LoopColor.inkSecondary)
                LoopMoneyText(amount: purchase.amount, size: 30)
                if let window = purchase.returnWindow {
                    ReturnWindowBar(window: window)
                }
            }
        }
    }

    @ViewBuilder
    private func lifecycle(_ payload: Payload) -> some View {
        LoopDetailSection(title: "In your loop") {
            VStack(spacing: 0) {
                linkRow(
                    title: "Return",
                    value: payload.returnRecord?.status.label ?? (payload.purchase.returnWindow?.state.label ?? "Not returnable"),
                    symbol: "arrow.uturn.backward",
                    tone: payload.returnRecord?.status.tone ?? .neutral,
                    destination: payload.returnRecord.map { AppDestination.returnDetail($0.id) }
                )
                LoopDivider()
                linkRow(
                    title: "Refund",
                    value: payload.refund?.status.label ?? "None expected",
                    symbol: "arrow.down.left.circle",
                    tone: payload.refund?.status.tone ?? .neutral,
                    destination: payload.refund.map { AppDestination.refund($0.id) }
                )
                LoopDivider()
                linkRow(
                    title: "Warranty",
                    value: payload.warranty?.status.label ?? "Not recorded",
                    symbol: "shield.lefthalf.filled",
                    tone: payload.warranty?.status.tone ?? .neutral,
                    destination: payload.warranty.map { AppDestination.warranty($0.id) }
                )
                LoopDivider()
                linkRow(
                    title: "Owned item",
                    value: payload.ownedItem.map { $0.isSold ? "Sold" : $0.condition.label } ?? "Not tracked",
                    symbol: "shippingbox",
                    tone: .neutral,
                    destination: payload.ownedItem.map { AppDestination.ownedItem($0.id) }
                )
                if let transactionID = payload.purchase.transactionID {
                    LoopDivider()
                    linkRow(
                        title: "Money",
                        value: MoneyFormatter.string(payload.purchase.amount),
                        symbol: "arrow.left.arrow.right",
                        tone: .neutral,
                        destination: .transaction(transactionID)
                    )
                }
            }
        }
    }

    private func linkRow(
        title: String,
        value: String,
        symbol: String,
        tone: LoopTone,
        destination: AppDestination?
    ) -> some View {
        Button {
            guard let destination else { return }
            router.push(destination)
        } label: {
            HStack(spacing: LoopSpacing.md) {
                LoopGlyph(symbol: symbol, tone: tone, size: 34)
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                Spacer(minLength: LoopSpacing.sm)
                Text(value)
                    .font(LoopFont.footnote)
                    .foregroundStyle(LoopColor.inkSecondary)
                    .multilineTextAlignment(.trailing)
                if destination != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LoopColor.inkTertiary)
                }
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(LoopPressStyle())
        .disabled(destination == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private func details(_ purchase: Purchase) -> some View {
        LoopDetailSection(title: "Purchase details") {
            VStack(spacing: LoopSpacing.sm) {
                LoopDetailRow(label: "Merchant", value: purchase.merchant)
                LoopDivider()
                LoopDetailRow(label: "Purchased", value: LoopDate.medium(purchase.purchasedAt))
                if let order = purchase.orderNumber {
                    LoopDivider()
                    LoopDetailRow(label: "Order", value: order)
                }
                if let category = purchase.category {
                    LoopDivider()
                    LoopDetailRow(label: "Category", value: category)
                }
                if let window = purchase.returnWindow {
                    LoopDivider()
                    LoopDetailRow(label: "Return deadline", value: LoopDate.medium(window.deadline))
                    if let policy = window.policyNote {
                        LoopDivider()
                        VStack(alignment: .leading, spacing: 2) {
                            LoopEyebrow(text: "Policy")
                            Text(policy)
                                .font(LoopFont.footnote)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, LoopSpacing.xs)
                    }
                }
            }
        }
    }

    private func receiptSection(_ payload: Payload) -> some View {
        LoopDetailSection(
            title: "Documents",
            trailingTitle: "Attach",
            trailingAction: { router.present(.attachDocument(.purchase(payload.purchase.id))) }
        ) {
            if payload.documents.isEmpty {
                VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                    Label("No receipt attached", systemImage: "exclamationmark.circle")
                        .font(LoopFont.subheadline)
                        .foregroundStyle(LoopColor.caution)
                    Text("A receipt protects this return and any warranty claim.")
                        .font(LoopFont.caption)
                        .foregroundStyle(LoopColor.inkSecondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(payload.documents.enumerated()), id: \.element.id) { index, document in
                        DocumentRow(document: document)
                        if index < payload.documents.count - 1 { LoopDivider() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actions(_ payload: Payload) -> some View {
        VStack(spacing: LoopSpacing.md) {
            if payload.returnRecord == nil, payload.purchase.returnWindow?.isExpired == false {
                LoopButton(title: "Start a return", symbol: "arrow.uturn.backward") {
                    router.present(.startReturn(purchaseID: payload.purchase.id))
                }
            }
            if let item = payload.ownedItem, !item.isSold {
                LoopSecondaryButton(title: "Prepare to sell", symbol: "tag") {
                    router.present(.newSale(ownedItemID: item.id))
                }
                if payload.warranty == nil {
                    LoopSecondaryButton(title: "Add warranty", symbol: "shield.lefthalf.filled") {
                        router.present(.editWarranty(ownedItemID: item.id, warrantyID: nil))
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            let purchase = try await loop.purchaseService.purchase(id: purchaseID, accountID: accountID)
            async let documents = loop.documentService.documents(
                for: .purchase(purchaseID), accountID: accountID
            )
            async let returns = loop.returnService.returns(accountID: accountID)
            async let refunds = loop.refundService.refunds(accountID: accountID)
            async let warranties = loop.warrantyService.warranties(accountID: accountID)
            async let items = loop.purchaseService.ownedItems(accountID: accountID)

            let (docs, allReturns, allRefunds, allWarranties, allItems) =
                try await (documents, returns, refunds, warranties, items)

            let ownedItem = allItems.first { $0.purchaseID == purchaseID }
            state = .loaded(
                Payload(
                    purchase: purchase,
                    documents: docs,
                    returnRecord: allReturns.first { $0.purchaseID == purchaseID },
                    refund: allRefunds.first { $0.purchaseID == purchaseID },
                    warranty: allWarranties.first { $0.ownedItemID == ownedItem?.id },
                    ownedItem: ownedItem
                )
            )
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

/// Visual return-window countdown.
struct ReturnWindowBar: View {
    let window: ReturnWindow

    private var progress: Double {
        let total = Double(window.policyDays)
        guard total > 0 else { return 1 }
        let used = total - Double(window.daysRemaining)
        return min(max(used / total, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
            HStack {
                Text("Return window")
                    .font(LoopFont.caption)
                    .foregroundStyle(LoopColor.inkTertiary)
                Spacer()
                LoopStatusBadge(
                    title: LoopDate.deadline(window.deadline),
                    tone: window.state.tone,
                    symbol: window.isExpired ? "clock.badge.xmark" : "clock"
                )
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(LoopColor.surfaceSunken)
                    Capsule()
                        .fill(window.state.tone.foreground)
                        .frame(width: max(4, proxy.size.width * progress))
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Return window, \(LoopDate.deadline(window.deadline))")
    }
}
