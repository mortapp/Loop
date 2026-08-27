import SwiftUI

struct LeadsView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[Lead]> = .idle
    @State private var filter: LeadFilter = .open
    @State private var query = ""

    nonisolated enum LeadFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
        case open, all, converted, closed

        var id: String { rawValue }

        var label: String {
            switch self {
            case .open: return "Open"
            case .all: return "All"
            case .converted: return "Converted"
            case .closed: return "Closed"
            }
        }

        func matches(_ lead: Lead) -> Bool {
            switch self {
            case .all: return true
            case .open: return lead.status.isOpen
            case .converted: return lead.status == .converted
            case .closed: return lead.status == .lost || lead.status == .unqualified
            }
        }
    }

    private var visible: [Lead] {
        (state.value ?? []).filter {
            filter.matches($0) && (query.isEmpty || $0.name.localizedStandardContains(query))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                LoopFilterChips(values: LeadFilter.allCases, selection: $filter) { $0.label }
                    .padding(.horizontal, -LoopSpacing.gutter)

                LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { _ in
                    if visible.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "person.crop.circle.badge.plus",
                                title: "No leads here",
                                message: "Leads are the start of every job. Add one and LOOP will remind you to follow up.",
                                actionTitle: "New lead",
                                action: { router.present(.newLead) }
                            )
                        }
                    } else {
                        LoopRowGroup(items: visible) { lead in
                            LoopNavigationRow {
                                router.push(.lead(lead.id))
                            } content: {
                                LeadRow(lead: lead)
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
        .navigationTitle("Leads")
        .searchable(text: $query, prompt: "Lead name")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.newLead) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New lead")
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.leadService.leads(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct LeadDetailView: View {
    let leadID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<Lead> = .idle
    @State private var isConverting = false
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 3, retry: { Task { await load() } }) { lead in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    LoopCard(padding: LoopSpacing.xl, isRaised: true) {
                        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                            Text(lead.name)
                                .font(LoopFont.display(24, weight: .semibold))
                                .foregroundStyle(LoopColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            LoopStatusBadge(
                                title: lead.status.label,
                                tone: lead.status.tone,
                                symbol: lead.status.symbolName
                            )
                            if let value = lead.estimatedValue {
                                LoopMoneyText(amount: value, size: 26)
                                    .padding(.top, LoopSpacing.xs)
                            }
                        }
                    }

                    LoopDetailSection(title: "Lead") {
                        VStack(spacing: LoopSpacing.sm) {
                            if let contact = lead.contactLabel {
                                LoopDetailRow(label: "Contact", value: contact)
                                LoopDivider()
                            }
                            LoopDetailRow(label: "Source", value: lead.source.label)
                            LoopDivider()
                            LoopDetailRow(label: "Created", value: LoopDate.medium(lead.createdAt))
                            if let followUp = lead.nextFollowUp {
                                LoopDivider()
                                LoopDetailRow(
                                    label: "Follow up",
                                    value: LoopDate.relative(followUp),
                                    valueColor: lead.isFollowUpDue ? LoopColor.critical : LoopColor.ink
                                )
                            }
                        }
                    }

                    if let note = lead.note {
                        LoopDetailSection(title: "Note") {
                            Text(note)
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(spacing: LoopSpacing.md) {
                        if lead.status.isOpen {
                            LoopButton(
                                title: "Convert to opportunity",
                                symbol: "arrow.turn.up.right",
                                isLoading: isConverting
                            ) {
                                Task { await convert(lead) }
                            }
                        }
                        if let opportunityID = lead.opportunityID {
                            LoopSecondaryButton(title: "View opportunity", symbol: "chart.line.uptrend.xyaxis") {
                                router.push(.opportunity(opportunityID))
                            }
                        }
                        if let customerID = lead.customerID {
                            LoopSecondaryButton(title: "View customer", symbol: "person") {
                                router.push(.customer(customerID))
                            }
                        }
                        LoopSecondaryButton(title: "Edit lead", symbol: "pencil") {
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
        .navigationTitle("Lead")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing, onDismiss: { Task { await load() } }) {
            LeadEditorView(lead: state.value)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func convert(_ lead: Lead) async {
        guard let accountID = appState.activeAccountID else { return }
        isConverting = true
        defer { isConverting = false }
        do {
            let opportunity = try await loop.leadService.convertToOpportunity(
                leadID: lead.id, accountID: accountID
            )
            LoopHaptics.success()
            await load()
            router.push(.opportunity(opportunity.id))
        } catch {
            LoopHaptics.error()
            LoopLog.failure(LoopLog.data, "convert lead", error)
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.leadService.lead(id: leadID, accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct LeadEditorView: View {
    let lead: Lead?

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var contact = ""
    @State private var source: LeadSource = .referral
    @State private var status: LeadStatus = .new
    @State private var estimatedValue: Decimal = 0
    @State private var hasFollowUp = true
    @State private var followUp = LoopDate.adding(days: 3, to: Date())
    @State private var note = ""
    @State private var isSaving = false
    @State private var error: LoopError?

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        LoopEditorScaffold(
            title: lead == nil ? "New lead" : "Edit lead",
            isSaveEnabled: isValid && !isSaving,
            onCancel: { dismiss() },
            onSave: { Task { await save() } }
        ) {
            LoopTextField(
                label: "Name",
                text: $name,
                placeholder: "Marcus Johnson",
                capitalization: .words,
                contentType: .name,
                errorMessage: name.isEmpty && isSaving ? "A name is required" : nil,
                isRequired: true
            )
            LoopTextField(
                label: "Contact",
                text: $contact,
                placeholder: "Email or phone",
                keyboard: .emailAddress,
                capitalization: .never
            )

            VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                LoopEyebrow(text: "Source")
                Picker("Source", selection: $source) {
                    ForEach(LeadSource.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(LoopColor.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                LoopEyebrow(text: "Status")
                Picker("Status", selection: $status) {
                    ForEach([LeadStatus.new, .contacted, .qualified, .unqualified, .lost]) {
                        Text($0.label).tag($0)
                    }
                }
                .pickerStyle(.menu)
                .tint(LoopColor.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            LoopCurrencyField(label: "Estimated value", value: $estimatedValue)

            Toggle("Schedule a follow-up", isOn: $hasFollowUp)
                .font(LoopFont.subheadline)
            if hasFollowUp {
                DatePicker("Follow up on", selection: $followUp, displayedComponents: .date)
                    .font(LoopFont.subheadline)
            }

            LoopTextEditor(label: "Notes", text: $note)

            if let error {
                Text(error.message)
                    .font(LoopFont.footnote)
                    .foregroundStyle(LoopColor.critical)
            }
        }
        .onAppear(perform: prefill)
    }

    private func prefill() {
        guard let lead else { return }
        name = lead.name
        contact = lead.contactLabel ?? ""
        source = lead.source
        status = lead.status
        estimatedValue = lead.estimatedValue?.value ?? 0
        hasFollowUp = lead.nextFollowUp != nil
        followUp = lead.nextFollowUp ?? LoopDate.adding(days: 3, to: Date())
        note = lead.note ?? ""
    }

    private func save() async {
        guard let accountID = appState.activeAccountID, isValid else { return }
        isSaving = true
        defer { isSaving = false }
        let record = Lead(
            id: lead?.id ?? UUID(),
            accountID: accountID,
            name: name.trimmingCharacters(in: .whitespaces),
            contactLabel: contact.isEmpty ? nil : contact,
            source: source,
            status: status,
            estimatedValue: estimatedValue > 0 ? MoneyAmount(MoneyFormatter.rounded(estimatedValue)) : nil,
            note: note.isEmpty ? nil : note,
            createdAt: lead?.createdAt ?? Date(),
            nextFollowUp: hasFollowUp ? followUp : nil,
            customerID: lead?.customerID,
            opportunityID: lead?.opportunityID,
            isArchived: false
        )
        do {
            _ = try await loop.leadService.save(lead: record)
            LoopHaptics.success()
            dismiss()
        } catch {
            LoopHaptics.error()
            self.error = LoopError.map(error)
        }
    }
}
