import SwiftUI

/// LOOP's post-purchase layer: deadlines, returns, refunds, warranties, receipts.
struct ProtectView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<ProtectOverview> = .idle

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 5, retry: { Task { await load() } }) { overview in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    metrics(overview)
                    windows(overview)
                    refunds(overview)
                    warranties(overview)
                    missingReceipts(overview)
                    directory
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Protect")
        .task { await load() }
        .refreshable { await load() }
    }

    private func metrics(_ overview: ProtectOverview) -> some View {
        HStack(spacing: LoopSpacing.md) {
            LoopMetricCard(
                label: "At stake",
                value: MoneyFormatter.compactString(overview.moneyAtStake),
                detail: "\(overview.outstandingRefunds.count) refund\(overview.outstandingRefunds.count == 1 ? "" : "s") outstanding",
                symbol: "hourglass",
                valueColor: overview.moneyAtStake.isZero ? LoopColor.ink : LoopColor.caution
            )
            LoopMetricCard(
                label: "Recovered",
                value: MoneyFormatter.compactString(overview.recoveredAllTime),
                detail: "All time through LOOP",
                symbol: "checkmark.seal",
                valueColor: LoopColor.positive
            )
        }
    }

    @ViewBuilder
    private func windows(_ overview: ProtectOverview) -> some View {
        VStack(alignment: .leading, spacing: LoopSpacing.md) {
            LoopSectionHeader(
                title: "Return windows",
                subtitle: "Still open, closing soonest first",
                count: overview.activeReturnWindows.count
            ) {
                LoopInlineAction(title: "Returns") { router.push(.returns) }
            }
            if overview.activeReturnWindows.isEmpty {
                LoopCard {
                    LoopEmptyState(
                        symbol: "clock.badge.checkmark",
                        title: "No open return windows",
                        message: "When you record a purchase with a return policy, its countdown appears here."
                    )
                }
            } else {
                LoopRowGroup(items: overview.activeReturnWindows) { purchase in
                    LoopNavigationRow {
                        router.push(.purchase(purchase.id))
                    } content: {
                        LoopListRow(
                            title: purchase.itemName,
                            subtitle: purchase.merchant,
                            symbol: "arrow.uturn.backward",
                            tone: purchase.returnWindow?.state.tone ?? .neutral
                        ) {
                            if let deadline = purchase.returnWindow?.deadline {
                                LoopDeadlineView(date: deadline, compact: true)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func refunds(_ overview: ProtectOverview) -> some View {
        if !overview.outstandingRefunds.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(title: "Money owed to you", count: overview.outstandingRefunds.count) {
                    LoopInlineAction(title: "All") { router.push(.refunds) }
                }
                LoopRowGroup(items: overview.outstandingRefunds) { refund in
                    LoopNavigationRow {
                        router.push(.refund(refund.id))
                    } content: {
                        RefundRow(refund: refund)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func warranties(_ overview: ProtectOverview) -> some View {
        if !overview.expiringWarranties.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(title: "Warranties ending", count: overview.expiringWarranties.count) {
                    LoopInlineAction(title: "All") { router.push(.warranties) }
                }
                LoopRowGroup(items: overview.expiringWarranties) { warranty in
                    LoopNavigationRow {
                        router.push(.warranty(warranty.id))
                    } content: {
                        LoopListRow(
                            title: warranty.itemName,
                            subtitle: warranty.provider,
                            symbol: warranty.status.symbolName,
                            tone: warranty.status.tone
                        ) {
                            if let end = warranty.coverageEnd {
                                LoopDeadlineView(date: end, compact: true)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func missingReceipts(_ overview: ProtectOverview) -> some View {
        if !overview.missingReceipts.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(
                    title: "Missing receipts",
                    subtitle: "Returns are harder without them",
                    count: overview.missingReceipts.count
                )
                LoopRowGroup(items: overview.missingReceipts) { purchase in
                    LoopNavigationRow {
                        router.push(.purchase(purchase.id))
                    } content: {
                        LoopListRow(
                            title: purchase.itemName,
                            subtitle: "\(purchase.merchant) · \(MoneyFormatter.string(purchase.amount))",
                            symbol: "doc.text.magnifyingglass",
                            tone: .caution
                        )
                    }
                }
            }
        }
    }

    private var directory: some View {
        LoopCard(padding: 0) {
            VStack(spacing: 0) {
                directoryRow("Returns", "arrow.uturn.backward", .returns)
                LoopDivider(inset: LoopSpacing.lg)
                directoryRow("Refunds", "arrow.down.left.circle", .refunds)
                LoopDivider(inset: LoopSpacing.lg)
                directoryRow("Warranties", "shield.lefthalf.filled", .warranties)
                LoopDivider(inset: LoopSpacing.lg)
                directoryRow("Receipts & documents", "doc.on.doc", .documents)
            }
        }
    }

    private func directoryRow(_ title: String, _ symbol: String, _ destination: AppDestination) -> some View {
        Button {
            router.push(destination)
        } label: {
            LoopListRow(title: title, symbol: symbol, tone: .accent)
                .padding(.horizontal, LoopSpacing.lg)
                .padding(.vertical, LoopSpacing.md)
        }
        .buttonStyle(LoopPressStyle())
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.protectionService.overview(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct RefundRow: View {
    let refund: Refund

    var body: some View {
        HStack(spacing: LoopSpacing.md) {
            LoopGlyph(symbol: refund.status.symbolName, tone: refund.status.tone)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(refund.merchant) refund")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .lineLimit(1)
                Text(refund.isOverdue
                     ? "Overdue · \(LoopDate.ageDescription(since: refund.openedAt, noun: "waiting"))"
                     : "\(refund.itemName) · \(refund.status.label)")
                    .font(LoopFont.caption)
                    .foregroundStyle(refund.isOverdue ? LoopColor.critical : LoopColor.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: LoopSpacing.sm)
            LoopMoneyText(
                amount: refund.receivedAmount ?? refund.expectedAmount,
                size: 16,
                tone: refund.status.isSettled ? .positive : .neutral
            )
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
