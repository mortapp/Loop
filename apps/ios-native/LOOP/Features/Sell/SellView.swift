import SwiftUI

/// Turning what you own back into money.
struct SellView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<ResaleSummary> = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                if appState.isSampleMode { SampleModeBanner() }

                LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { summary in
                    VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                        metrics(summary)
                        readyToSell(summary)
                        saleGroup("Listed", summary.listed)
                        saleGroup("Buyer committed", summary.pending)
                        saleGroup("Drafts", summary.drafts)
                        soldSection(summary)
                    }
                }
            }
            .loopGutter()
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("Sell")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.newSale(ownedItemID: nil))
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New sale")
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func metrics(_ summary: ResaleSummary) -> some View {
        HStack(spacing: LoopSpacing.md) {
            LoopMetricCard(
                label: "Proceeds",
                value: MoneyFormatter.compactString(summary.proceedsThisYear),
                detail: "Net, this year",
                symbol: "arrow.down.left.circle",
                valueColor: LoopColor.positive
            )
            LoopMetricCard(
                label: "Potential",
                value: MoneyFormatter.compactString(summary.estimatedPotential),
                detail: "Your estimates, not market prices",
                symbol: "sparkle"
            )
        }
    }

    @ViewBuilder
    private func readyToSell(_ summary: ResaleSummary) -> some View {
        VStack(alignment: .leading, spacing: LoopSpacing.md) {
            LoopSectionHeader(
                title: "Ready to sell",
                subtitle: "Things you own that could become money",
                count: summary.readyToSell.count
            )
            if summary.readyToSell.isEmpty {
                LoopCard {
                    LoopEmptyState(
                        symbol: "tag",
                        title: "Nothing flagged yet",
                        message: "As items age or you add resale estimates, LOOP will suggest what's worth selling."
                    )
                }
            } else {
                VStack(spacing: LoopSpacing.md) {
                    ForEach(summary.readyToSell) { candidate in
                        CandidateCard(candidate: candidate) {
                            router.push(.ownedItem(candidate.item.id))
                        } onSell: {
                            router.present(.newSale(ownedItemID: candidate.item.id))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func saleGroup(_ title: String, _ sales: [SaleRecord]) -> some View {
        if !sales.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(title: title, count: sales.count)
                LoopRowGroup(items: sales) { sale in
                    LoopNavigationRow {
                        router.push(.sale(sale.id))
                    } content: {
                        SaleRow(sale: sale)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func soldSection(_ summary: ResaleSummary) -> some View {
        if !summary.sold.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(title: "Sold", count: summary.sold.count) {
                    LoopInlineAction(title: "All sales") { router.push(.sales) }
                }
                LoopRowGroup(items: summary.sold) { sale in
                    LoopNavigationRow {
                        router.push(.sale(sale.id))
                    } content: {
                        SaleRow(sale: sale)
                    }
                }
            }
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.resaleService.summary(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct CandidateCard: View {
    let candidate: ResaleCandidate
    let onOpen: () -> Void
    let onSell: () -> Void

    var body: some View {
        LoopCard {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                Button(action: onOpen) {
                    HStack(alignment: .top, spacing: LoopSpacing.md) {
                        LoopGlyph(symbol: "shippingbox", tone: .accent, size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.item.name)
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(LoopColor.ink)
                                .multilineTextAlignment(.leading)
                            Text("\(candidate.reason) · paid \(MoneyFormatter.string(candidate.item.originalPrice))")
                                .font(LoopFont.caption)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        if let estimate = candidate.estimate {
                            VStack(alignment: .trailing, spacing: 1) {
                                LoopMoneyText(amount: estimate, size: 17)
                                Text(candidate.estimateIsUserProvided ? "your estimate" : "estimate")
                                    .font(LoopFont.caption)
                                    .foregroundStyle(LoopColor.inkTertiary)
                            }
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(LoopPressStyle())

                LoopSecondaryButton(title: "Prepare sale", symbol: "tag", action: onSell)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct SaleRow: View {
    let sale: SaleRecord

    var body: some View {
        HStack(spacing: LoopSpacing.md) {
            LoopGlyph(symbol: sale.status.symbolName, tone: sale.status.tone)
            VStack(alignment: .leading, spacing: 2) {
                Text(sale.itemName)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .lineLimit(1)
                Text([sale.platform, sale.status.label].compactMap { $0 }.joined(separator: " · "))
                    .font(LoopFont.caption)
                    .foregroundStyle(LoopColor.inkSecondary)
            }
            Spacer(minLength: LoopSpacing.sm)
            VStack(alignment: .trailing, spacing: 1) {
                LoopMoneyText(
                    amount: sale.netProceeds,
                    size: 16,
                    tone: sale.status == .sold ? .positive : .neutral
                )
                Text("net")
                    .font(LoopFont.caption)
                    .foregroundStyle(LoopColor.inkTertiary)
            }
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Full list of sales, all statuses.
struct SalesListView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[SaleRecord]> = .idle

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { sales in
                VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                    if sales.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "tag",
                                title: "No sales yet",
                                message: "Prepare a sale from anything you own and LOOP will track it to net proceeds."
                            )
                        }
                    } else {
                        LoopRowGroup(items: sales) { sale in
                            LoopNavigationRow {
                                router.push(.sale(sale.id))
                            } content: {
                                SaleRow(sale: sale)
                            }
                        }
                    }
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("All sales")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.resaleService.sales(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}
