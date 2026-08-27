import SwiftUI

/// Full ledger with filtering and month sections.
struct TransactionListView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[MoneyTransaction]> = .idle
    @State private var filter: MoneyFilter = .all

    private var grouped: [(String, [MoneyTransaction])] {
        let filtered = (state.value ?? []).filter { filter.matches($0) }
        let groups = Dictionary(grouping: filtered) { LoopDate.monthKey($0.occurredAt) }
        return groups
            .sorted { lhs, rhs in
                (lhs.value.first?.occurredAt ?? .distantPast) > (rhs.value.first?.occurredAt ?? .distantPast)
            }
            .map { ($0.key, $0.value.sorted { $0.occurredAt > $1.occurredAt }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                LoopFilterChips(values: MoneyFilter.allCases, selection: $filter) { $0.label }
                    .padding(.horizontal, -LoopSpacing.gutter)

                LoadableView(state: state, loadingRows: 6, retry: { Task { await load() } }) { _ in
                    if grouped.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "line.3.horizontal.decrease.circle",
                                title: "No matching activity",
                                message: "Try a different filter to see more of your ledger."
                            )
                        }
                    } else {
                        ForEach(grouped, id: \.0) { month, transactions in
                            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                                LoopEyebrow(text: month)
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
            }
            .loopGutter()
            .padding(.vertical, LoopSpacing.md)
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.moneyService.transactions(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

/// One transaction, with its link back into the record that produced it.
struct TransactionDetailView: View {
    let transactionID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<MoneyTransaction> = .idle

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 3, retry: { Task { await load() } }) { transaction in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    amountHeader(transaction)

                    LoopDetailSection(title: "Details") {
                        VStack(spacing: LoopSpacing.sm) {
                            LoopDetailRow(label: "Type", value: transaction.type.label)
                            LoopDivider()
                            LoopDetailRow(label: "Date", value: LoopDate.medium(transaction.occurredAt))
                            if let merchant = transaction.merchantOrSource {
                                LoopDivider()
                                LoopDetailRow(label: "Source", value: merchant)
                            }
                            if let category = transaction.category {
                                LoopDivider()
                                LoopDetailRow(label: "Category", value: category)
                            }
                        }
                    }

                    if let note = transaction.note {
                        LoopDetailSection(title: "Note") {
                            Text(note)
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let related = transaction.relatedRecord {
                        LoopButton(title: related.label, symbol: "arrow.up.right") {
                            router.push(related.destination)
                        }
                    }
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func amountHeader(_ transaction: MoneyTransaction) -> some View {
        LoopCard(padding: LoopSpacing.xl, isRaised: true) {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                HStack(spacing: LoopSpacing.md) {
                    LoopGlyph(
                        symbol: transaction.type.symbolName,
                        tone: transaction.direction == .incoming ? .positive : .neutral,
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.title)
                            .font(LoopFont.display(20, weight: .semibold))
                            .foregroundStyle(LoopColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        LoopStatusBadge(
                            title: transaction.status.label,
                            tone: transaction.status.tone,
                            symbol: transaction.status.symbolName
                        )
                    }
                    Spacer(minLength: 0)
                }
                Text(MoneyFormatter.signedString(transaction.signedAmount))
                    .font(LoopFont.amount(34, weight: .semibold))
                    .foregroundStyle(
                        transaction.direction == .incoming ? LoopColor.positive : LoopColor.ink
                    )
                    .accessibilityLabel(MoneyFormatter.accessibleString(transaction.signedAmount))
            }
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        state = .loading
        do {
            state = .loaded(try await loop.moneyService.transaction(id: transactionID, accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}
