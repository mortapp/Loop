import SwiftUI

struct OpportunitiesView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[Opportunity]> = .idle

    private var active: [Opportunity] { (state.value ?? []).filter(\.stage.isActive) }
    private var closed: [Opportunity] { (state.value ?? []).filter { !$0.stage.isActive } }

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { opportunities in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    if opportunities.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "chart.line.uptrend.xyaxis",
                                title: "No opportunities yet",
                                message: "Convert a qualified lead, or create one directly, to start tracking work you could win.",
                                actionTitle: "New opportunity",
                                action: { router.present(.newOpportunity(leadID: nil)) }
                            )
                        }
                    } else {
                        pipelineBoard(active)
                        group("Closed", closed)
                    }
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Opportunities")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.newOpportunity(leadID: nil)) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New opportunity")
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func pipelineBoard(_ opportunities: [Opportunity]) -> some View {
        ForEach([OpportunityStage.open, .proposal, .negotiation], id: \.self) { stage in
            let stageItems = opportunities.filter { $0.stage == stage }
            if !stageItems.isEmpty {
                VStack(alignment: .leading, spacing: LoopSpacing.md) {
                    LoopSectionHeader(
                        title: stage.label,
                        subtitle: MoneyFormatter.string(MoneyAmount.sum(stageItems.map(\.estimatedValue))),
                        count: stageItems.count
                    )
                    LoopRowGroup(items: stageItems) { opportunity in
                        LoopNavigationRow {
                            router.push(.opportunity(opportunity.id))
                        } content: {
                            OpportunityRow(opportunity: opportunity)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ opportunities: [Opportunity]) -> some View {
        if !opportunities.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(title: title, count: opportunities.count)
                LoopRowGroup(items: opportunities) { opportunity in
                    LoopNavigationRow {
                        router.push(.opportunity(opportunity.id))
                    } content: {
                        OpportunityRow(opportunity: opportunity)
                    }
                }
            }
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.opportunityService.opportunities(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct OpportunityRow: View {
    let opportunity: Opportunity

    var body: some View {
        HStack(spacing: LoopSpacing.md) {
            LoopGlyph(symbol: opportunity.stage.symbolName, tone: opportunity.stage.tone)
            VStack(alignment: .leading, spacing: 2) {
                Text(opportunity.title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .lineLimit(1)
                HStack(spacing: LoopSpacing.xs) {
                    Text(opportunity.stage.label)
                    if let close = opportunity.expectedCloseDate {
                        Text("·")
                        Text(LoopDate.relative(close))
                            .foregroundStyle(opportunity.needsAttention ? LoopColor.caution : LoopColor.inkSecondary)
                    }
                }
                .font(LoopFont.caption)
                .foregroundStyle(LoopColor.inkSecondary)
            }
            Spacer(minLength: LoopSpacing.sm)
            LoopMoneyText(amount: opportunity.estimatedValue, size: 15, tone: .muted)
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct OpportunityDetailView: View {
    let opportunityID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<Payload> = .idle
    @State private var isEditing = false
    @State private var isRecordingIncome = false

    nonisolated struct Payload: Sendable {
        var opportunity: Opportunity
        var customer: Customer?
        var quotes: [Quote]
        var earnings: [BusinessEarning]
    }

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 3, retry: { Task { await load() } }) { payload in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    LoopCard(padding: LoopSpacing.xl, isRaised: true) {
                        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                            Text(payload.opportunity.title)
                                .font(LoopFont.display(24, weight: .semibold))
                                .foregroundStyle(LoopColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if let customer = payload.customer {
                                Text(customer.displayName)
                                    .font(LoopFont.subheadline)
                                    .foregroundStyle(LoopColor.inkSecondary)
                            }
                            LoopStatusBadge(
                                title: payload.opportunity.stage.label,
                                tone: payload.opportunity.stage.tone,
                                symbol: payload.opportunity.stage.symbolName
                            )
                            LoopMoneyText(amount: payload.opportunity.estimatedValue, size: 28)
                                .padding(.top, LoopSpacing.xs)
                        }
                    }

                    stagePicker(payload.opportunity)

                    if let detail = payload.opportunity.detail {
                        LoopDetailSection(title: "Scope") {
                            Text(detail)
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    LoopDetailSection(title: "Details") {
                        VStack(spacing: LoopSpacing.sm) {
                            LoopDetailRow(label: "Created", value: LoopDate.medium(payload.opportunity.createdAt))
                            if let close = payload.opportunity.expectedCloseDate {
                                LoopDivider()
                                LoopDetailRow(
                                    label: "Expected close",
                                    value: LoopDate.relative(close),
                                    valueColor: payload.opportunity.needsAttention ? LoopColor.caution : LoopColor.ink
                                )
                            }
                            if let leadID = payload.opportunity.leadID {
                                LoopDivider()
                                Button {
                                    router.push(.lead(leadID))
                                } label: {
                                    LoopDetailRow(label: "Origin", value: "From a lead ›", valueColor: LoopColor.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !payload.quotes.isEmpty {
                        VStack(alignment: .leading, spacing: LoopSpacing.md) {
                            LoopSectionHeader(title: "Quotes", count: payload.quotes.count)
                            LoopRowGroup(items: payload.quotes) { quote in
                                LoopNavigationRow {
                                    router.push(.quote(quote.id))
                                } content: {
                                    QuoteRow(quote: quote)
                                }
                            }
                        }
                    }

                    if !payload.earnings.isEmpty {
                        LoopDetailSection(title: "Income recorded") {
                            VStack(spacing: LoopSpacing.sm) {
                                ForEach(payload.earnings) { earning in
                                    LoopDetailRow(
                                        label: LoopDate.medium(earning.receivedAt),
                                        value: MoneyFormatter.string(earning.amount),
                                        valueColor: LoopColor.positive,
                                        isMonospaced: true
                                    )
                                }
                            }
                        }
                    }

                    VStack(spacing: LoopSpacing.md) {
                        LoopButton(title: "New quote", symbol: "doc.badge.plus") {
                            router.present(.newQuote(customerID: payload.opportunity.customerID))
                        }
                        if payload.opportunity.stage == .won && payload.earnings.isEmpty {
                            LoopButton(
                                title: "Record income",
                                symbol: "dollarsign.circle",
                                isLoading: isRecordingIncome,
                                prominence: .ink
                            ) {
                                Task { await recordIncome(payload) }
                            }
                        }
                        LoopSecondaryButton(title: "Edit opportunity", symbol: "pencil") {
                            isEditing = true
                        }
                    }
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Opportunity")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing, onDismiss: { Task { await load() } }) {
            OpportunityEditorView(opportunity: state.value?.opportunity, leadID: nil)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func stagePicker(_ opportunity: Opportunity) -> some View {
        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
            LoopEyebrow(text: "Stage")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LoopSpacing.sm) {
                    ForEach(OpportunityStage.allCases) { stage in
                        let isSelected = stage == opportunity.stage
                        Button {
                            Task { await setStage(stage) }
                        } label: {
                            Text(stage.label)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : LoopColor.inkSecondary)
                                .padding(.horizontal, LoopSpacing.md)
                                .frame(minHeight: 36)
                                .background(isSelected ? LoopColor.ink : LoopColor.surface, in: .capsule)
                                .overlay {
                                    Capsule().strokeBorder(
                                        isSelected ? Color.clear : LoopColor.hairline, lineWidth: 1
                                    )
                                }
                        }
                        .buttonStyle(LoopPressStyle())
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
            }
        }
    }

    private func setStage(_ stage: OpportunityStage) async {
        guard let accountID = appState.activeAccountID, let payload = state.value else { return }
        do {
            let updated = try await loop.opportunityService.setStage(
                opportunityID: payload.opportunity.id, stage: stage, accountID: accountID
            )
            LoopHaptics.selection()
            var newPayload = payload
            newPayload.opportunity = updated
            withAnimation(LoopMotion.quick) { state = .loaded(newPayload) }
        } catch {
            LoopHaptics.error()
        }
    }

    private func recordIncome(_ payload: Payload) async {
        guard let accountID = appState.activeAccountID else { return }
        isRecordingIncome = true
        defer { isRecordingIncome = false }
        let amount = payload.quotes.first(where: { $0.status == .accepted })?.total
            ?? payload.opportunity.estimatedValue
        let earning = BusinessEarning(
            id: UUID(),
            accountID: accountID,
            title: payload.opportunity.title,
            customerID: payload.opportunity.customerID,
            opportunityID: payload.opportunity.id,
            quoteID: payload.quotes.first(where: { $0.status == .accepted })?.id,
            amount: amount,
            receivedAt: Date(),
            source: .opportunity,
            transactionID: nil,
            note: nil
        )
        do {
            _ = try await loop.businessService.recordEarning(earning)
            LoopHaptics.success()
            await load()
        } catch {
            LoopHaptics.error()
            LoopLog.failure(LoopLog.data, "record earning", error)
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            let opportunity = try await loop.opportunityService.opportunity(
                id: opportunityID, accountID: accountID
            )
            async let quotes = loop.quoteService.quotes(accountID: accountID)
            async let earnings = loop.businessService.earnings(accountID: accountID)
            let customer: Customer? = if let customerID = opportunity.customerID {
                try? await loop.customerService.customer(id: customerID, accountID: accountID)
            } else {
                nil
            }
            let (allQuotes, allEarnings) = try await (quotes, earnings)
            state = .loaded(
                Payload(
                    opportunity: opportunity,
                    customer: customer,
                    quotes: allQuotes.filter { $0.opportunityID == opportunityID },
                    earnings: allEarnings.filter { $0.opportunityID == opportunityID }
                )
            )
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct OpportunityEditorView: View {
    let opportunity: Opportunity?
    let leadID: UUID?

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var customers: [Customer] = []
    @State private var title = ""
    @State private var detail = ""
    @State private var customerID: UUID?
    @State private var estimatedValue: Decimal = 0
    @State private var stage: OpportunityStage = .open
    @State private var hasCloseDate = true
    @State private var closeDate = LoopDate.adding(days: 21, to: Date())
    @State private var isSaving = false
    @State private var error: LoopError?

    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        LoopEditorScaffold(
            title: opportunity == nil ? "New opportunity" : "Edit opportunity",
            isSaveEnabled: isValid && !isSaving,
            onCancel: { dismiss() },
            onSave: { Task { await save() } }
        ) {
            LoopTextField(label: "Title", text: $title, placeholder: "Website redesign", capitalization: .sentences, isRequired: true)

            VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                LoopEyebrow(text: "Customer")
                Picker("Customer", selection: $customerID) {
                    Text("No customer").tag(UUID?.none)
                    ForEach(customers) { Text($0.displayName).tag(UUID?.some($0.id)) }
                }
                .pickerStyle(.menu)
                .tint(LoopColor.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            LoopCurrencyField(label: "Estimated value", value: $estimatedValue)

            VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                LoopEyebrow(text: "Stage")
                Picker("Stage", selection: $stage) {
                    ForEach(OpportunityStage.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(LoopColor.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle("Expected close date", isOn: $hasCloseDate)
                .font(LoopFont.subheadline)
            if hasCloseDate {
                DatePicker("Closes", selection: $closeDate, displayedComponents: .date)
                    .font(LoopFont.subheadline)
            }

            LoopTextEditor(label: "Scope", text: $detail)

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
        if let opportunity {
            title = opportunity.title
            detail = opportunity.detail ?? ""
            customerID = opportunity.customerID
            estimatedValue = opportunity.estimatedValue.value
            stage = opportunity.stage
            hasCloseDate = opportunity.expectedCloseDate != nil
            closeDate = opportunity.expectedCloseDate ?? LoopDate.adding(days: 21, to: Date())
        } else if let leadID,
                  let lead = try? await loop.leadService.lead(id: leadID, accountID: accountID) {
            title = "\(lead.name) opportunity"
            customerID = lead.customerID
            estimatedValue = lead.estimatedValue?.value ?? 0
        }
    }

    private func save() async {
        guard let accountID = appState.activeAccountID else { return }
        isSaving = true
        defer { isSaving = false }
        let record = Opportunity(
            id: opportunity?.id ?? UUID(),
            accountID: accountID,
            title: title.trimmingCharacters(in: .whitespaces),
            detail: detail.isEmpty ? nil : detail,
            customerID: customerID,
            leadID: opportunity?.leadID ?? leadID,
            estimatedValue: MoneyAmount(MoneyFormatter.rounded(estimatedValue)),
            stage: stage,
            expectedCloseDate: hasCloseDate ? closeDate : nil,
            quoteIDs: opportunity?.quoteIDs ?? [],
            note: opportunity?.note,
            createdAt: opportunity?.createdAt ?? Date(),
            isArchived: false
        )
        do {
            _ = try await loop.opportunityService.save(opportunity: record)
            LoopHaptics.success()
            dismiss()
        } catch {
            LoopHaptics.error()
            self.error = LoopError.map(error)
        }
    }
}
