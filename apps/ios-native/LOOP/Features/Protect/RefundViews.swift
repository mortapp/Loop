import SwiftUI

/// Everything LOOP is chasing, plus everything it has recovered.
struct RefundsListView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[Refund]> = .idle

    private var outstanding: [Refund] { (state.value ?? []).filter(\.status.isOutstanding) }
    private var settled: [Refund] { (state.value ?? []).filter { !$0.status.isOutstanding } }

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 3, retry: { Task { await load() } }) { refunds in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    if refunds.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "arrow.down.left.circle",
                                title: "No refunds yet",
                                message: "When a return reaches the refund stage, LOOP tracks the money until it actually lands."
                            )
                        }
                    } else {
                        LoopMetricCard(
                            label: "Recovered all time",
                            value: MoneyFormatter.string(
                                MoneyAmount.sum(refunds.filter { $0.status.isSettled }.map(\.settledAmount))
                            ),
                            detail: "\(refunds.filter { $0.status.isSettled }.count) refunds settled",
                            symbol: "checkmark.seal",
                            valueColor: LoopColor.positive
                        )
                    }
                    group("Outstanding", outstanding)
                    group("Settled", settled)
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Refunds")
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func group(_ title: String, _ refunds: [Refund]) -> some View {
        if !refunds.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(title: title, count: refunds.count)
                LoopRowGroup(items: refunds) { refund in
                    LoopNavigationRow {
                        router.push(.refund(refund.id))
                    } content: {
                        RefundRow(refund: refund)
                    }
                }
            }
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.refundService.refunds(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

/// One refund and its reconciliation into Money.
struct RefundDetailView: View {
    let refundID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<Refund> = .idle
    @State private var isSettling = false
    @State private var showsSettleConfirmation = false

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 3, retry: { Task { await load() } }) { refund in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    header(refund)

                    if refund.isOverdue {
                        LoopCard(tint: LoopColor.criticalSoft) {
                            HStack(alignment: .top, spacing: LoopSpacing.md) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(LoopColor.critical)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("This refund is overdue")
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(LoopColor.ink)
                                    Text("It's been \(refund.ageInDays) days. Contact \(refund.merchant) with your shipping evidence.")
                                        .font(LoopFont.caption)
                                        .foregroundStyle(LoopColor.inkSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }

                    LoopDetailSection(title: "Refund") {
                        VStack(spacing: LoopSpacing.sm) {
                            LoopDetailRow(label: "Merchant", value: refund.merchant)
                            LoopDivider()
                            LoopDetailRow(label: "Item", value: refund.itemName)
                            LoopDivider()
                            LoopDetailRow(
                                label: "Expected",
                                value: MoneyFormatter.string(refund.expectedAmount),
                                isMonospaced: true
                            )
                            if let received = refund.receivedAmount {
                                LoopDivider()
                                LoopDetailRow(
                                    label: "Received",
                                    value: MoneyFormatter.string(received),
                                    valueColor: LoopColor.positive,
                                    isMonospaced: true
                                )
                            }
                            LoopDivider()
                            LoopDetailRow(label: "Opened", value: LoopDate.medium(refund.openedAt))
                            if let expected = refund.expectedDate {
                                LoopDivider()
                                LoopDetailRow(label: "Expected by", value: LoopDate.medium(expected))
                            }
                            if let received = refund.receivedDate {
                                LoopDivider()
                                LoopDetailRow(label: "Received on", value: LoopDate.medium(received))
                            }
                        }
                    }

                    if let note = refund.note {
                        LoopDetailSection(title: "Note") {
                            Text(note)
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    actions(refund)
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Refund")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Mark this refund as received?",
            isPresented: $showsSettleConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes, the money landed") {
                Task { await settle() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("LOOP will clear the pending transaction in Money and count this toward recovered money.")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func header(_ refund: Refund) -> some View {
        LoopCard(padding: LoopSpacing.xl, isRaised: true) {
            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                Text("\(refund.merchant) refund")
                    .font(LoopFont.display(22, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                LoopStatusBadge(
                    title: refund.status.label,
                    tone: refund.status.tone,
                    symbol: refund.status.symbolName
                )
                Text(MoneyFormatter.string(refund.receivedAmount ?? refund.expectedAmount))
                    .font(LoopFont.amount(34, weight: .semibold))
                    .foregroundStyle(refund.status.isSettled ? LoopColor.positive : LoopColor.ink)
                    .padding(.top, LoopSpacing.xs)
                    .accessibilityLabel(
                        MoneyFormatter.accessibleString(
                            refund.receivedAmount ?? refund.expectedAmount, showsSign: false
                        )
                    )
                if refund.status.isOutstanding {
                    Text(LoopDate.ageDescription(since: refund.openedAt, noun: "Waiting"))
                        .font(LoopFont.footnote)
                        .foregroundStyle(LoopColor.inkSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func actions(_ refund: Refund) -> some View {
        VStack(spacing: LoopSpacing.md) {
            if refund.status.isOutstanding {
                LoopButton(
                    title: "Mark refund received",
                    symbol: "checkmark.seal",
                    isLoading: isSettling
                ) {
                    showsSettleConfirmation = true
                }
            }
            if let returnID = refund.returnRecordID {
                LoopSecondaryButton(title: "View return", symbol: "arrow.uturn.backward") {
                    router.push(.returnDetail(returnID))
                }
            }
            if let purchaseID = refund.purchaseID {
                LoopSecondaryButton(title: "View purchase", symbol: "bag") {
                    router.push(.purchase(purchaseID))
                }
            }
            if let transactionID = refund.transactionID {
                LoopSecondaryButton(title: "View in Money", symbol: "arrow.left.arrow.right") {
                    router.push(.transaction(transactionID))
                }
            }
        }
    }

    private func settle() async {
        guard let accountID = appState.activeAccountID, let refund = state.value else { return }
        isSettling = true
        defer { isSettling = false }
        do {
            let updated = try await loop.refundService.markReceived(
                refundID: refund.id, amount: refund.expectedAmount, accountID: accountID
            )
            LoopHaptics.success()
            withAnimation(LoopMotion.standard) { state = .loaded(updated) }
        } catch {
            LoopHaptics.error()
            LoopLog.failure(LoopLog.data, "settle refund", error)
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.refundService.refund(id: refundID, accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}
