import SwiftUI
import Observation

@MainActor
@Observable
final class MoneyViewModel {
    private(set) var state: LoadState<Payload> = .idle
    var filter: MoneyFilter

    private let money: any MoneyService
    private let accountID: UUID

    nonisolated struct Payload: Sendable {
        var summary: MoneySummary
        var transactions: [MoneyTransaction]
    }

    init(money: any MoneyService, accountID: UUID, filter: MoneyFilter) {
        self.money = money
        self.accountID = accountID
        self.filter = filter
    }

    var filteredTransactions: [MoneyTransaction] {
        (state.value?.transactions ?? []).filter { filter.matches($0) }
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let summary = money.summary(accountID: accountID)
            async let transactions = money.transactions(accountID: accountID)
            state = .loaded(Payload(summary: try await summary, transactions: try await transactions))
        } catch {
            LoopLog.failure(LoopLog.data, "money", error)
            state = .failed(LoopError.map(error))
        }
    }
}

/// The central ledger. Everything LOOP recovers, earns or spends lands here.
struct MoneyView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var viewModel: MoneyViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                if appState.isSampleMode { SampleModeBanner() }

                if let viewModel {
                    LoadableView(state: viewModel.state, loadingRows: 5, retry: {
                        Task { await viewModel.load() }
                    }) { payload in
                        content(payload, viewModel: viewModel)
                    }
                } else {
                    LoopLoadingState(rows: 5)
                }
            }
            .loopGutter()
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("Money")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.search)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search LOOP")
            }
        }
        .refreshable { await viewModel?.load() }
        .task {
            guard viewModel == nil, let accountID = appState.activeAccountID else { return }
            let model = MoneyViewModel(
                money: loop.moneyService,
                accountID: accountID,
                filter: appState.preferences.defaultMoneyFilter
            )
            viewModel = model
            await model.load()
        }
    }

    @ViewBuilder
    private func content(_ payload: MoneyViewModel.Payload, viewModel: MoneyViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: LoopSpacing.xl) {
            NetMovementCard(summary: payload.summary)

            HStack(spacing: LoopSpacing.md) {
                LoopMetricCard(
                    label: "Recovered",
                    value: MoneyFormatter.compactString(payload.summary.recovered),
                    detail: "Refunds settled",
                    symbol: "arrow.uturn.backward",
                    valueColor: LoopColor.positive
                )
                LoopMetricCard(
                    label: "Pending in",
                    value: MoneyFormatter.compactString(payload.summary.pendingIncoming),
                    detail: "Not landed yet",
                    symbol: "hourglass",
                    valueColor: LoopColor.caution
                )
            }

            HStack(spacing: LoopSpacing.md) {
                LoopMetricCard(
                    label: "Business",
                    value: MoneyFormatter.compactString(payload.summary.businessEarnings),
                    detail: "Income closed",
                    symbol: "briefcase"
                )
                LoopMetricCard(
                    label: "Resale",
                    value: MoneyFormatter.compactString(payload.summary.resaleProceeds),
                    detail: "Net proceeds",
                    symbol: "tag"
                )
            }

            quickLinks

            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(title: "Activity", subtitle: "Every movement in your loop") {
                    LoopInlineAction(title: "All") { router.push(.transactions) }
                }
                LoopFilterChips(values: MoneyFilter.allCases, selection: $viewModel.filter) { $0.label }
                    .padding(.horizontal, -LoopSpacing.gutter)

                let transactions = Array(viewModel.filteredTransactions.prefix(12))
                if transactions.isEmpty {
                    LoopCard {
                        LoopEmptyState(
                            symbol: "tray",
                            title: "Nothing here yet",
                            message: "No transactions match this filter. Money added through purchases, refunds, resales and business income will appear here."
                        )
                    }
                } else {
                    LoopRowGroup(items: transactions) { transaction in
                        LoopNavigationRow {
                            router.push(.transaction(transaction.id))
                        } content: {
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
            }
        }
    }

    private var quickLinks: some View {
        LoopCard(padding: 0) {
            VStack(spacing: 0) {
                quickLink("Purchases", "bag", "Receipts, return windows, warranties") {
                    router.push(.purchases)
                }
                LoopDivider(inset: LoopSpacing.lg)
                quickLink("Protect", "shield.lefthalf.filled", "Deadlines, returns and refunds") {
                    router.push(.protect)
                }
                LoopDivider(inset: LoopSpacing.lg)
                quickLink("Recovered money", "arrow.down.left.circle", "Everything LOOP has clawed back") {
                    router.push(.refunds)
                }
            }
        }
    }

    private func quickLink(
        _ title: String,
        _ symbol: String,
        _ subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            LoopListRow(title: title, subtitle: subtitle, symbol: symbol, tone: .accent)
                .padding(.horizontal, LoopSpacing.lg)
                .padding(.vertical, LoopSpacing.md)
        }
        .buttonStyle(LoopPressStyle())
    }
}

/// Hero card: net movement for the current period with an in/out bar.
struct NetMovementCard: View {
    let summary: MoneySummary

    private var inRatio: Double {
        let incoming = NSDecimalNumber(decimal: summary.incoming.value).doubleValue
        let outgoing = NSDecimalNumber(decimal: summary.outgoing.value).doubleValue
        let total = incoming + outgoing
        guard total > 0 else { return 0.5 }
        return incoming / total
    }

    var body: some View {
        LoopCard(padding: LoopSpacing.xl, isRaised: true) {
            VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                    Text("NET MOVEMENT · \(summary.periodLabel.uppercased())")
                        .font(LoopFont.eyebrow)
                        .kerning(0.9)
                        .foregroundStyle(LoopColor.inkTertiary)
                    Text(MoneyFormatter.signedString(summary.netMovement))
                        .font(LoopFont.amount(40, weight: .semibold))
                        .foregroundStyle(summary.netMovement.isNegative ? LoopColor.ink : LoopColor.positive)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .accessibilityLabel(
                            "Net movement this period, "
                            + MoneyFormatter.accessibleString(summary.netMovement)
                        )
                }

                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        Capsule()
                            .fill(LoopColor.positive)
                            .frame(width: max(6, proxy.size.width * inRatio - 2))
                        Capsule()
                            .fill(LoopColor.ink.opacity(0.28))
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)

                HStack(spacing: LoopSpacing.xl) {
                    legend(
                        "In",
                        MoneyFormatter.string(summary.incoming),
                        LoopColor.positive
                    )
                    legend(
                        "Out",
                        MoneyFormatter.string(summary.outgoing),
                        LoopColor.ink.opacity(0.4)
                    )
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func legend(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: LoopSpacing.sm) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(LoopFont.caption)
                    .foregroundStyle(LoopColor.inkTertiary)
                Text(value)
                    .font(LoopFont.amount(15, weight: .medium))
                    .foregroundStyle(LoopColor.ink)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// One ledger line.
struct TransactionRow: View {
    let transaction: MoneyTransaction

    var body: some View {
        HStack(spacing: LoopSpacing.md) {
            LoopGlyph(
                symbol: transaction.type.symbolName,
                tone: transaction.direction == .incoming ? .positive : .neutral
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .lineLimit(1)
                HStack(spacing: LoopSpacing.xs) {
                    Text(LoopDate.medium(transaction.occurredAt))
                    Text("·")
                    Text(transaction.type.label)
                }
                .font(LoopFont.caption)
                .foregroundStyle(LoopColor.inkSecondary)
            }
            Spacer(minLength: LoopSpacing.sm)
            VStack(alignment: .trailing, spacing: 3) {
                LoopMoneyText(amount: transaction.signedAmount, size: 16, showsSign: true)
                if transaction.status != .cleared {
                    LoopStatusBadge(
                        title: transaction.status.label,
                        tone: transaction.status.tone,
                        symbol: transaction.status.symbolName
                    )
                }
            }
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { MoneyView() }
        .environment(\.loop, .preview)
        .environment(AppState(environment: .preview))
        .environment(AppRouter())
}
