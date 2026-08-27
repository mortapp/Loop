import SwiftUI

/// One sale: status timeline, proceeds breakdown and the Money connection.
struct SaleDetailView: View {
    let saleID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<SaleRecord> = .idle
    @State private var isCompleting = false
    @State private var showsConfirmation = false

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { sale in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    header(sale)

                    LoopDetailSection(title: "Proceeds") {
                        VStack(spacing: LoopSpacing.sm) {
                            LoopDetailRow(
                                label: "Gross",
                                value: MoneyFormatter.string(sale.grossAmount),
                                isMonospaced: true
                            )
                            LoopDivider()
                            LoopDetailRow(
                                label: "Platform fees",
                                value: "−" + MoneyFormatter.string(sale.fees),
                                isMonospaced: true
                            )
                            LoopDivider()
                            LoopDetailRow(
                                label: "Shipping",
                                value: "−" + MoneyFormatter.string(sale.shippingCost),
                                isMonospaced: true
                            )
                            LoopDivider()
                            HStack {
                                Text("Net proceeds")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(LoopColor.ink)
                                Spacer()
                                LoopMoneyText(amount: sale.netProceeds, size: 20, tone: .positive)
                            }
                            .padding(.top, LoopSpacing.xs)
                        }
                    }

                    LoopDetailSection(title: "Progress") {
                        LoopTimeline(steps: sale.timeline)
                    }

                    LoopDetailSection(title: "Details") {
                        VStack(spacing: LoopSpacing.sm) {
                            LoopDetailRow(label: "Platform", value: sale.platform ?? "Not set")
                            if let listed = sale.listedDate {
                                LoopDivider()
                                LoopDetailRow(label: "Listed", value: LoopDate.medium(listed))
                            }
                            if let sold = sale.soldDate {
                                LoopDivider()
                                LoopDetailRow(label: "Sold", value: LoopDate.medium(sold))
                            }
                        }
                    }

                    if let note = sale.note {
                        LoopDetailSection(title: "Note") {
                            Text(note)
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    actions(sale)
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Sale")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Record this sale as complete?",
            isPresented: $showsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes, I've been paid") { Task { await complete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("LOOP will add the net proceeds to your Money ledger as resale income.")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func header(_ sale: SaleRecord) -> some View {
        LoopCard(padding: LoopSpacing.xl, isRaised: true) {
            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                Text(sale.itemName)
                    .font(LoopFont.display(22, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                LoopStatusBadge(
                    title: sale.status.label,
                    tone: sale.status.tone,
                    symbol: sale.status.symbolName
                )
                Text(MoneyFormatter.string(sale.netProceeds))
                    .font(LoopFont.amount(34, weight: .semibold))
                    .foregroundStyle(sale.status == .sold ? LoopColor.positive : LoopColor.ink)
                    .padding(.top, LoopSpacing.xs)
                Text("net after \(MoneyFormatter.string(sale.totalCosts)) in costs")
                    .font(LoopFont.footnote)
                    .foregroundStyle(LoopColor.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func actions(_ sale: SaleRecord) -> some View {
        VStack(spacing: LoopSpacing.md) {
            if sale.status != .sold && sale.status != .cancelled {
                LoopButton(
                    title: "Mark as sold",
                    symbol: "checkmark.seal",
                    isLoading: isCompleting
                ) {
                    showsConfirmation = true
                }
                LoopSecondaryButton(title: "Edit sale", symbol: "pencil") {
                    router.present(.newSale(ownedItemID: sale.ownedItemID))
                }
            }
            LoopSecondaryButton(title: "View item", symbol: "shippingbox") {
                router.push(.ownedItem(sale.ownedItemID))
            }
            if let transactionID = sale.transactionID {
                LoopSecondaryButton(title: "View in Money", symbol: "arrow.left.arrow.right") {
                    router.push(.transaction(transactionID))
                }
            }
        }
    }

    private func complete() async {
        guard let accountID = appState.activeAccountID else { return }
        isCompleting = true
        defer { isCompleting = false }
        do {
            let updated = try await loop.resaleService.markSold(saleID: saleID, accountID: accountID)
            LoopHaptics.success()
            withAnimation(LoopMotion.standard) { state = .loaded(updated) }
        } catch {
            LoopHaptics.error()
            LoopLog.failure(LoopLog.data, "complete sale", error)
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.resaleService.sale(id: saleID, accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

/// Create or edit a sale, with live net-proceeds maths.
struct SaleEditorView: View {
    let sale: SaleRecord?
    let ownedItemID: UUID?

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var items: [OwnedItem] = []
    @State private var selectedItemID: UUID?
    @State private var platform: String = ""
    @State private var gross: Decimal = 0
    @State private var fees: Decimal = 0
    @State private var shipping: Decimal = 0
    @State private var status: SaleStatus = .draft
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var error: LoopError?

    private var netProceeds: MoneyAmount {
        MoneyAmount(MoneyFormatter.rounded(gross - fees - shipping))
    }

    private var isValid: Bool { selectedItemID != nil && gross >= 0 }

    var body: some View {
        LoopEditorScaffold(
            title: sale == nil ? "Prepare sale" : "Edit sale",
            isSaveEnabled: isValid && !isSaving,
            onCancel: { dismiss() },
            onSave: { Task { await save() } }
        ) {
            VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                LoopEyebrow(text: "Item")
                Picker("Item", selection: $selectedItemID) {
                    Text("Choose an item").tag(UUID?.none)
                    ForEach(items) { item in
                        Text(item.name).tag(UUID?.some(item.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(LoopColor.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            LoopTextField(
                label: "Platform",
                text: $platform,
                placeholder: "eBay, Swappa, Marketplace…",
                capitalization: .words
            )

            LoopCurrencyField(label: "Gross sale price", value: $gross, isRequired: true)
            LoopCurrencyField(label: "Platform fees", value: $fees)
            LoopCurrencyField(label: "Shipping cost", value: $shipping)

            LoopCard(tint: LoopColor.positiveSoft) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Net proceeds")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(LoopColor.ink)
                        Text("gross − fees − shipping")
                            .font(LoopFont.caption)
                            .foregroundStyle(LoopColor.inkSecondary)
                    }
                    Spacer()
                    LoopMoneyText(amount: netProceeds, size: 22, tone: .positive)
                }
                .accessibilityElement(children: .combine)
            }

            VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                LoopEyebrow(text: "Status")
                Picker("Status", selection: $status) {
                    ForEach([SaleStatus.draft, .listed, .pending]) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            LoopTextEditor(label: "Notes", text: $note, minHeight: 90)

            if let error {
                Text(error.message)
                    .font(LoopFont.footnote)
                    .foregroundStyle(LoopColor.critical)
            }
        }
        .task { await prefill() }
    }

    private func prefill() async {
        guard let accountID = appState.activeAccountID else { return }
        items = (try? await loop.purchaseService.ownedItems(accountID: accountID)) ?? []
        if let sale {
            selectedItemID = sale.ownedItemID
            platform = sale.platform ?? ""
            gross = sale.grossAmount.value
            fees = sale.fees.value
            shipping = sale.shippingCost.value
            status = sale.status
            note = sale.note ?? ""
        } else {
            selectedItemID = ownedItemID
            if let ownedItemID, let item = items.first(where: { $0.id == ownedItemID }) {
                gross = item.estimatedResaleValue?.value ?? 0
            }
        }
    }

    private func save() async {
        guard let accountID = appState.activeAccountID, let itemID = selectedItemID else { return }
        isSaving = true
        defer { isSaving = false }
        let item = items.first { $0.id == itemID }
        let record = SaleRecord(
            id: sale?.id ?? UUID(),
            accountID: accountID,
            ownedItemID: itemID,
            itemName: item?.name ?? sale?.itemName ?? "Item",
            platform: platform.isEmpty ? nil : platform,
            grossAmount: MoneyAmount(MoneyFormatter.rounded(gross)),
            fees: MoneyAmount(MoneyFormatter.rounded(fees)),
            shippingCost: MoneyAmount(MoneyFormatter.rounded(shipping)),
            listedDate: status == .draft ? sale?.listedDate : (sale?.listedDate ?? Date()),
            soldDate: sale?.soldDate,
            status: status,
            transactionID: sale?.transactionID,
            note: note.isEmpty ? nil : note
        )
        do {
            _ = try await loop.resaleService.save(sale: record)
            LoopHaptics.success()
            dismiss()
        } catch {
            LoopHaptics.error()
            self.error = LoopError.map(error)
        }
    }
}

/// One owned item: where it came from, how it's protected, what it's worth.
struct OwnedItemDetailView: View {
    let itemID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<OwnedItem> = .idle

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 3, retry: { Task { await load() } }) { item in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    LoopCard(padding: LoopSpacing.xl, isRaised: true) {
                        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                            Text(item.name)
                                .font(LoopFont.display(22, weight: .semibold))
                                .foregroundStyle(LoopColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(item.merchant) · owned \(item.ageInDays) days")
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                            HStack(spacing: LoopSpacing.sm) {
                                LoopStatusBadge(title: item.condition.label, tone: .neutral, symbol: "sparkles")
                                if item.isSold {
                                    LoopStatusBadge(title: "Sold", tone: .positive, symbol: "checkmark")
                                } else if item.isMarkedForSale {
                                    LoopStatusBadge(title: "For sale", tone: .accent, symbol: "tag")
                                }
                            }
                        }
                    }

                    LoopDetailSection(title: "Value") {
                        VStack(spacing: LoopSpacing.sm) {
                            LoopDetailRow(
                                label: "Paid",
                                value: MoneyFormatter.string(item.originalPrice),
                                isMonospaced: true
                            )
                            if let estimate = item.estimatedResaleValue {
                                LoopDivider()
                                LoopDetailRow(
                                    label: item.estimateIsUserProvided ? "Your estimate" : "Estimate",
                                    value: MoneyFormatter.string(estimate),
                                    isMonospaced: true
                                )
                                LoopDivider()
                                Text("Estimates are entered by you. LOOP does not price items against a live market.")
                                    .font(LoopFont.caption)
                                    .foregroundStyle(LoopColor.inkTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let note = item.note {
                        LoopDetailSection(title: "Note") {
                            Text(note)
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(spacing: LoopSpacing.md) {
                        if !item.isSold {
                            LoopButton(title: "Prepare sale", symbol: "tag") {
                                router.present(.newSale(ownedItemID: item.id))
                            }
                        }
                        if let saleID = item.saleID {
                            LoopSecondaryButton(title: "View sale", symbol: "shippingbox") {
                                router.push(.sale(saleID))
                            }
                        }
                        if let purchaseID = item.purchaseID {
                            LoopSecondaryButton(title: "View purchase", symbol: "bag") {
                                router.push(.purchase(purchaseID))
                            }
                        }
                        if let warrantyID = item.warrantyID {
                            LoopSecondaryButton(title: "View warranty", symbol: "shield.lefthalf.filled") {
                                router.push(.warranty(warrantyID))
                            }
                        } else {
                            LoopSecondaryButton(title: "Add warranty", symbol: "shield.lefthalf.filled") {
                                router.present(.editWarranty(ownedItemID: item.id, warrantyID: nil))
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
        .navigationTitle("Item")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.purchaseService.ownedItem(id: itemID, accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}
