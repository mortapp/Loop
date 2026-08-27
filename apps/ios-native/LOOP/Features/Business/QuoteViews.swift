import SwiftUI

struct QuotesView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[Quote]> = .idle

    private var awaiting: [Quote] { (state.value ?? []).filter(\.status.isAwaitingResponse) }
    private var drafts: [Quote] { (state.value ?? []).filter { $0.status == .draft } }
    private var settled: [Quote] {
        (state.value ?? []).filter { !$0.status.isAwaitingResponse && $0.status != .draft }
    }

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { quotes in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    if quotes.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "doc.plaintext",
                                title: "No quotes yet",
                                message: "Build a quote with line items and LOOP will total it, track the response and chase it in Today.",
                                actionTitle: "New quote",
                                action: { router.present(.newQuote(customerID: nil)) }
                            )
                        }
                    } else {
                        group("Awaiting response", awaiting)
                        group("Drafts", drafts)
                        group("Closed", settled)
                    }
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Quotes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.newQuote(customerID: nil)) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New quote")
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func group(_ title: String, _ quotes: [Quote]) -> some View {
        if !quotes.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(
                    title: title,
                    subtitle: MoneyFormatter.string(MoneyAmount.sum(quotes.map(\.total))),
                    count: quotes.count
                )
                LoopRowGroup(items: quotes) { quote in
                    LoopNavigationRow {
                        router.push(.quote(quote.id))
                    } content: {
                        QuoteRow(quote: quote)
                    }
                }
            }
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.quoteService.quotes(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct QuoteRow: View {
    let quote: Quote

    var body: some View {
        HStack(spacing: LoopSpacing.md) {
            LoopGlyph(symbol: quote.status.symbolName, tone: quote.status.tone)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(quote.reference) · \(quote.title)")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .lineLimit(1)
                HStack(spacing: LoopSpacing.xs) {
                    Text(quote.status.label)
                    if let expiry = quote.expiresAt, quote.status.isAwaitingResponse {
                        Text("·")
                        Text(LoopDate.deadline(expiry))
                            .foregroundStyle(quote.expiresSoon ? LoopColor.critical : LoopColor.inkSecondary)
                    }
                }
                .font(LoopFont.caption)
                .foregroundStyle(LoopColor.inkSecondary)
            }
            Spacer(minLength: LoopSpacing.sm)
            LoopMoneyText(amount: quote.total, size: 16)
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct QuoteDetailView: View {
    let quoteID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<Payload> = .idle
    @State private var isEditing = false
    @State private var isWorking = false

    nonisolated struct Payload: Sendable {
        var quote: Quote
        var customer: Customer?
    }

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { payload in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    header(payload)

                    LoopDetailSection(title: "Line items") {
                        VStack(spacing: LoopSpacing.sm) {
                            ForEach(payload.quote.lineItems) { item in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(item.name)
                                            .font(.system(.subheadline, weight: .medium))
                                            .foregroundStyle(LoopColor.ink)
                                        Spacer(minLength: LoopSpacing.sm)
                                        Text(MoneyFormatter.string(
                                            MoneyAmount(item.lineTotal, currencyCode: payload.quote.currencyCode)
                                        ))
                                        .font(LoopFont.amount(15, weight: .medium))
                                        .foregroundStyle(LoopColor.ink)
                                    }
                                    Text("\(item.quantity.formatted()) × \(MoneyFormatter.string(MoneyAmount(item.unitPrice, currencyCode: payload.quote.currencyCode)))"
                                         + (item.detail.map { " · \($0)" } ?? ""))
                                        .font(LoopFont.caption)
                                        .foregroundStyle(LoopColor.inkTertiary)
                                }
                                .accessibilityElement(children: .combine)
                                if item.id != payload.quote.lineItems.last?.id { LoopDivider() }
                            }

                            LoopDivider()
                            LoopDetailRow(
                                label: "Subtotal",
                                value: MoneyFormatter.string(payload.quote.subtotal),
                                isMonospaced: true
                            )
                            if payload.quote.discount > 0 {
                                LoopDetailRow(
                                    label: "Discount",
                                    value: "−" + MoneyFormatter.string(
                                        MoneyAmount(payload.quote.discount, currencyCode: payload.quote.currencyCode)
                                    ),
                                    isMonospaced: true
                                )
                            }
                            if payload.quote.taxRate > 0 {
                                LoopDetailRow(
                                    label: "Tax",
                                    value: MoneyFormatter.string(payload.quote.taxAmount),
                                    isMonospaced: true
                                )
                            }
                            HStack {
                                Text("Total")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(LoopColor.ink)
                                Spacer()
                                LoopMoneyText(amount: payload.quote.total, size: 22)
                            }
                            .padding(.top, LoopSpacing.xs)
                        }
                    }

                    LoopDetailSection(title: "Progress") {
                        LoopTimeline(steps: payload.quote.timeline)
                    }

                    LoopDetailSection(title: "Details") {
                        VStack(spacing: LoopSpacing.sm) {
                            LoopDetailRow(label: "Reference", value: payload.quote.reference, isMonospaced: true)
                            LoopDivider()
                            LoopDetailRow(label: "Issued", value: LoopDate.medium(payload.quote.issuedAt))
                            if let expiry = payload.quote.expiresAt {
                                LoopDivider()
                                LoopDetailRow(
                                    label: "Expires",
                                    value: LoopDate.medium(expiry),
                                    valueColor: payload.quote.expiresSoon ? LoopColor.critical : LoopColor.ink
                                )
                            }
                            if let customer = payload.customer {
                                LoopDivider()
                                Button {
                                    router.push(.customer(customer.id))
                                } label: {
                                    LoopDetailRow(
                                        label: "Customer",
                                        value: customer.displayName + " ›",
                                        valueColor: LoopColor.accent
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let note = payload.quote.note {
                        LoopDetailSection(title: "Note") {
                            Text(note)
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    actions(payload.quote)
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Quote")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing, onDismiss: { Task { await load() } }) {
            QuoteEditorView(quote: state.value?.quote, customerID: state.value?.quote.customerID)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func header(_ payload: Payload) -> some View {
        LoopCard(padding: LoopSpacing.xl, isRaised: true) {
            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                Text(payload.quote.title)
                    .font(LoopFont.display(24, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(payload.customer?.displayName ?? payload.quote.reference)
                    .font(LoopFont.subheadline)
                    .foregroundStyle(LoopColor.inkSecondary)
                LoopStatusBadge(
                    title: payload.quote.status.label,
                    tone: payload.quote.status.tone,
                    symbol: payload.quote.status.symbolName
                )
                Text(MoneyFormatter.string(payload.quote.total))
                    .font(LoopFont.amount(34, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .padding(.top, LoopSpacing.xs)
                    .accessibilityLabel(MoneyFormatter.accessibleString(payload.quote.total, showsSign: false))
            }
        }
    }

    @ViewBuilder
    private func actions(_ quote: Quote) -> some View {
        VStack(spacing: LoopSpacing.md) {
            switch quote.status {
            case .draft:
                LoopButton(title: "Mark as sent", symbol: "paperplane", isLoading: isWorking) {
                    Task { await setStatus(.sent) }
                }
            case .sent, .viewed:
                LoopButton(title: "Mark accepted", symbol: "checkmark.seal", isLoading: isWorking) {
                    Task { await setStatus(.accepted) }
                }
                LoopSecondaryButton(title: "Mark declined", symbol: "hand.thumbsdown") {
                    Task { await setStatus(.declined) }
                }
            default:
                EmptyView()
            }
            LoopSecondaryButton(title: "Duplicate quote", symbol: "doc.on.doc") {
                Task { await duplicate() }
            }
            if quote.status == .draft {
                LoopSecondaryButton(title: "Edit quote", symbol: "pencil") { isEditing = true }
            }
            if let opportunityID = quote.opportunityID {
                LoopSecondaryButton(title: "View opportunity", symbol: "chart.line.uptrend.xyaxis") {
                    router.push(.opportunity(opportunityID))
                }
            }
            Text("Accepting a quote moves its opportunity to Won. LOOP does not send the quote or take payment for you.")
                .font(LoopFont.caption)
                .foregroundStyle(LoopColor.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, LoopSpacing.xs)
        }
    }

    private func setStatus(_ status: QuoteStatus) async {
        guard let accountID = appState.activeAccountID else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let updated = try await loop.quoteService.setStatus(
                quoteID: quoteID, status: status, accountID: accountID
            )
            LoopHaptics.success()
            if var payload = state.value {
                payload.quote = updated
                withAnimation(LoopMotion.standard) { state = .loaded(payload) }
            }
        } catch {
            LoopHaptics.error()
            LoopLog.failure(LoopLog.data, "quote status", error)
        }
    }

    private func duplicate() async {
        guard let accountID = appState.activeAccountID else { return }
        do {
            let copy = try await loop.quoteService.duplicate(quoteID: quoteID, accountID: accountID)
            LoopHaptics.success()
            router.push(.quote(copy.id))
        } catch {
            LoopHaptics.error()
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            let quote = try await loop.quoteService.quote(id: quoteID, accountID: accountID)
            let customer: Customer? = if let customerID = quote.customerID {
                try? await loop.customerService.customer(id: customerID, accountID: accountID)
            } else {
                nil
            }
            state = .loaded(Payload(quote: quote, customer: customer))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

/// Quote builder with live subtotal and total maths.
struct QuoteEditorView: View {
    let quote: Quote?
    let customerID: UUID?

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var customers: [Customer] = []
    @State private var reference = ""
    @State private var title = ""
    @State private var selectedCustomerID: UUID?
    @State private var lineItems: [QuoteLineItem] = [QuoteLineItem(name: "")]
    @State private var discount: Decimal = 0
    @State private var taxPercent: Decimal = 0
    @State private var hasExpiry = true
    @State private var expiry = LoopDate.adding(days: 30, to: Date())
    @State private var note = ""
    @State private var isSaving = false
    @State private var error: LoopError?

    private var draft: Quote {
        Quote(
            id: quote?.id ?? UUID(),
            accountID: quote?.accountID ?? appState.activeAccountID ?? UUID(),
            reference: reference,
            title: title,
            customerID: selectedCustomerID,
            opportunityID: quote?.opportunityID,
            lineItems: lineItems.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty },
            discount: MoneyFormatter.rounded(discount),
            taxRate: taxPercent / 100,
            currencyCode: quote?.currencyCode ?? "USD",
            status: quote?.status ?? .draft,
            issuedAt: quote?.issuedAt ?? Date(),
            expiresAt: hasExpiry ? expiry : nil,
            respondedAt: quote?.respondedAt,
            note: note.isEmpty ? nil : note,
            isArchived: false
        )
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !draft.lineItems.isEmpty
    }

    var body: some View {
        LoopEditorScaffold(
            title: quote == nil ? "New quote" : "Edit quote",
            isSaveEnabled: isValid && !isSaving,
            onCancel: { dismiss() },
            onSave: { Task { await save() } }
        ) {
            LoopTextField(label: "Title", text: $title, placeholder: "Website redesign", isRequired: true)

            VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                LoopEyebrow(text: "Customer")
                Picker("Customer", selection: $selectedCustomerID) {
                    Text("No customer").tag(UUID?.none)
                    ForEach(customers) { Text($0.displayName).tag(UUID?.some($0.id)) }
                }
                .pickerStyle(.menu)
                .tint(LoopColor.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                HStack {
                    LoopEyebrow(text: "Line items")
                    Spacer()
                    Button {
                        withAnimation(LoopMotion.quick) {
                            lineItems.append(QuoteLineItem(name: ""))
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(LoopColor.accent)
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Add line item")
                }
                ForEach($lineItems) { $item in
                    LineItemEditor(item: $item) {
                        withAnimation(LoopMotion.quick) {
                            lineItems.removeAll { $0.id == item.id }
                        }
                    }
                }
            }

            LoopCurrencyField(label: "Discount", value: $discount)

            VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                LoopEyebrow(text: "Tax rate %")
                Stepper(
                    value: Binding(
                        get: { NSDecimalNumber(decimal: taxPercent).doubleValue },
                        set: { taxPercent = Decimal($0) }
                    ),
                    in: 0...30,
                    step: 0.5
                ) {
                    Text("\(NSDecimalNumber(decimal: taxPercent).doubleValue, specifier: "%.1f")%")
                        .font(LoopFont.amount(15, weight: .medium))
                        .foregroundStyle(LoopColor.ink)
                }
            }

            LoopCard(tint: LoopColor.surfaceSunken) {
                VStack(spacing: LoopSpacing.sm) {
                    LoopDetailRow(label: "Subtotal", value: MoneyFormatter.string(draft.subtotal), isMonospaced: true)
                    if discount > 0 {
                        LoopDetailRow(
                            label: "Discount",
                            value: "−" + MoneyFormatter.string(MoneyAmount(MoneyFormatter.rounded(discount))),
                            isMonospaced: true
                        )
                    }
                    if taxPercent > 0 {
                        LoopDetailRow(label: "Tax", value: MoneyFormatter.string(draft.taxAmount), isMonospaced: true)
                    }
                    LoopDivider()
                    HStack {
                        Text("Total")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(LoopColor.ink)
                        Spacer()
                        LoopMoneyText(amount: draft.total, size: 22)
                    }
                }
            }

            Toggle("Expires", isOn: $hasExpiry)
                .font(LoopFont.subheadline)
            if hasExpiry {
                DatePicker("Expiry date", selection: $expiry, displayedComponents: .date)
                    .font(LoopFont.subheadline)
            }

            LoopTextEditor(label: "Notes", text: $note)

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
        customers = (try? await loop.customerService.customers(accountID: accountID)) ?? []
        if let quote {
            reference = quote.reference
            title = quote.title
            selectedCustomerID = quote.customerID
            lineItems = quote.lineItems.isEmpty ? [QuoteLineItem(name: "")] : quote.lineItems
            discount = quote.discount
            taxPercent = quote.taxRate * 100
            hasExpiry = quote.expiresAt != nil
            expiry = quote.expiresAt ?? LoopDate.adding(days: 30, to: Date())
            note = quote.note ?? ""
        } else {
            selectedCustomerID = customerID
            reference = (try? await loop.quoteService.nextReference(accountID: accountID)) ?? "Q-1001"
        }
    }

    private func save() async {
        guard appState.activeAccountID != nil else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await loop.quoteService.save(quote: draft)
            LoopHaptics.success()
            dismiss()
        } catch {
            LoopHaptics.error()
            self.error = LoopError.map(error)
        }
    }
}

private struct LineItemEditor: View {
    @Binding var item: QuoteLineItem
    let onRemove: () -> Void

    @State private var quantityText: String = "1"
    @State private var priceText: String = ""

    var body: some View {
        LoopCard(padding: LoopSpacing.md, tint: LoopColor.surfaceSunken) {
            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                HStack {
                    TextField("Item name", text: $item.name)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(LoopColor.ink)
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(LoopColor.critical)
                            .frame(width: 44, height: 44, alignment: .trailing)
                    }
                    .accessibilityLabel("Remove line item")
                }
                HStack(spacing: LoopSpacing.md) {
                    labelledField("Qty", text: $quantityText) { newValue in
                        item.quantity = MoneyFormatter.parse(newValue) ?? 1
                    }
                    labelledField("Unit price", text: $priceText) { newValue in
                        item.unitPrice = MoneyFormatter.parse(newValue) ?? 0
                    }
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Total")
                            .font(LoopFont.caption)
                            .foregroundStyle(LoopColor.inkTertiary)
                        Text(MoneyFormatter.string(MoneyAmount(item.lineTotal)))
                            .font(LoopFont.amount(15, weight: .semibold))
                            .foregroundStyle(LoopColor.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .onAppear {
            quantityText = "\(item.quantity)"
            priceText = item.unitPrice == 0 ? "" : "\(item.unitPrice)"
        }
        .accessibilityElement(children: .contain)
    }

    private func labelledField(
        _ label: String,
        text: Binding<String>,
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(LoopFont.caption)
                .foregroundStyle(LoopColor.inkTertiary)
            TextField("0", text: text)
                .font(LoopFont.amount(15, weight: .medium))
                .keyboardType(.decimalPad)
                .onChange(of: text.wrappedValue) { _, newValue in onChange(newValue) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(label)
    }
}
