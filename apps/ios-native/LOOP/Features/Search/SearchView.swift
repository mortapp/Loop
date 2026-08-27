import SwiftUI

/// Unified search across every LOOP module.
struct SearchView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var category: SearchCategory = .all
    @State private var results: [SearchResult] = []
    @State private var error: LoopError?
    @State private var isSearching = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LoopFilterChips(values: SearchCategory.allCases, selection: $category) { $0.label }
                    .padding(.vertical, LoopSpacing.sm)

                LoopDivider()

                ScrollView {
                    VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                        if let error {
                            LoopErrorState(error: error) { Task { await search() } }
                        } else if query.isEmpty {
                            LoopEmptyState(
                                symbol: "magnifyingglass",
                                title: "Search everything",
                                message: "Purchases, transactions, returns, refunds, warranties, items, sales, leads, opportunities and quotes."
                            )
                        } else if results.isEmpty && !isSearching {
                            LoopEmptyState(
                                symbol: "questionmark.folder",
                                title: "No matches",
                                message: "Nothing in your LOOP matches “\(query)”."
                            )
                        } else {
                            LoopRowGroup(items: results) { result in
                                LoopNavigationRow {
                                    dismiss()
                                    router.open(result.source)
                                } content: {
                                    LoopListRow(
                                        title: result.title,
                                        subtitle: result.subtitle,
                                        symbol: result.symbolName,
                                        tone: result.tone
                                    ) {
                                        if let amount = result.amount {
                                            LoopMoneyText(amount: amount, size: 15, tone: .muted)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .loopGutter()
                    .padding(.vertical, LoopSpacing.lg)
                }
            }
            .background(LoopColor.canvas)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search LOOP")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, weight: .semibold))
                }
            }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                await search()
            }
            .task(id: category) { await search() }
        }
    }

    private func search() async {
        guard let accountID = appState.activeAccountID else { return }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            error = nil
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await loop.searchService.search(
                query: query, category: category, accountID: accountID
            )
            error = nil
        } catch {
            self.error = LoopError.map(error)
        }
    }
}

#Preview {
    SearchView()
        .environment(\.loop, .preview)
        .environment(AppState(environment: .preview))
        .environment(AppRouter())
}
