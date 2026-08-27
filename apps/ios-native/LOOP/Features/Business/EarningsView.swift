import SwiftUI

/// Business income. Every earning is mirrored into the Money ledger — Business
/// never keeps a balance of its own.
struct EarningsView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[BusinessEarning]> = .idle

    private var grouped: [(String, [BusinessEarning])] {
        let groups = Dictionary(grouping: state.value ?? []) { LoopDate.monthKey($0.receivedAt) }
        return groups
            .sorted { ($0.value.first?.receivedAt ?? .distantPast) > ($1.value.first?.receivedAt ?? .distantPast) }
            .map { ($0.key, $0.value.sorted { $0.receivedAt > $1.receivedAt }) }
    }

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { earnings in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    if earnings.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "dollarsign.circle",
                                title: "No income recorded",
                                message: "When you win an opportunity, record the income and LOOP adds it to your Money ledger."
                            )
                        }
                    } else {
                        LoopMetricCard(
                            label: "Total recorded",
                            value: MoneyFormatter.string(MoneyAmount.sum(earnings.map(\.amount))),
                            detail: "\(earnings.count) payments across your business",
                            symbol: "briefcase",
                            valueColor: LoopColor.positive
                        )
                        ForEach(grouped, id: \.0) { month, items in
                            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                                LoopEyebrow(text: month)
                                LoopRowGroup(items: items) { earning in
                                    LoopNavigationRow {
                                        if let transactionID = earning.transactionID {
                                            router.push(.transaction(transactionID))
                                        }
                                    } content: {
                                        LoopListRow(
                                            title: earning.title,
                                            subtitle: "\(earning.source.label) · \(LoopDate.medium(earning.receivedAt))",
                                            symbol: "dollarsign.circle",
                                            tone: .positive,
                                            showsChevron: earning.transactionID != nil
                                        ) {
                                            LoopMoneyText(amount: earning.amount, size: 16, tone: .positive)
                                        }
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
        }
        .background(LoopColor.canvas)
        .navigationTitle("Earnings")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.businessService.earnings(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}
