import SwiftUI

struct CustomersView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[Customer]> = .idle
    @State private var query = ""

    private var visible: [Customer] {
        (state.value ?? []).filter {
            query.isEmpty
                || $0.name.localizedStandardContains(query)
                || ($0.company?.localizedStandardContains(query) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { _ in
                VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                    if visible.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "person.2",
                                title: "No customers yet",
                                message: "Customers connect leads, opportunities, quotes and the income you earn.",
                                actionTitle: "New customer",
                                action: { router.present(.newCustomer) }
                            )
                        }
                    } else {
                        LoopRowGroup(items: visible) { customer in
                            LoopNavigationRow {
                                router.push(.customer(customer.id))
                            } content: {
                                HStack(spacing: LoopSpacing.md) {
                                    Text(customer.initials)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 38, height: 38)
                                        .background(LoopColor.ink, in: .circle)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(customer.name)
                                            .font(.system(.body, weight: .semibold))
                                            .foregroundStyle(LoopColor.ink)
                                        if let company = customer.company {
                                            Text(company)
                                                .font(LoopFont.caption)
                                                .foregroundStyle(LoopColor.inkSecondary)
                                        }
                                    }
                                    Spacer(minLength: LoopSpacing.sm)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(LoopColor.inkTertiary)
                                }
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                                .accessibilityElement(children: .combine)
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
        .navigationTitle("Customers")
        .searchable(text: $query, prompt: "Name or company")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.newCustomer) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New customer")
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.customerService.customers(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct CustomerDetailView: View {
    let customerID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<Payload> = .idle
    @State private var isEditing = false

    nonisolated struct Payload: Sendable {
        var customer: Customer
        var opportunities: [Opportunity]
        var quotes: [Quote]
        var earnings: [BusinessEarning]
    }

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 3, retry: { Task { await load() } }) { payload in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    LoopCard(padding: LoopSpacing.xl, isRaised: true) {
                        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                            Text(payload.customer.name)
                                .font(LoopFont.display(24, weight: .semibold))
                                .foregroundStyle(LoopColor.ink)
                            if let company = payload.customer.company {
                                Text(company)
                                    .font(LoopFont.subheadline)
                                    .foregroundStyle(LoopColor.inkSecondary)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: LoopSpacing.sm) {
                                Text("Earned")
                                    .font(LoopFont.footnote)
                                    .foregroundStyle(LoopColor.inkSecondary)
                                LoopMoneyText(
                                    amount: MoneyAmount.sum(payload.earnings.map(\.amount)),
                                    size: 22,
                                    tone: .positive
                                )
                            }
                            .padding(.top, LoopSpacing.xs)
                        }
                    }

                    LoopDetailSection(title: "Contact") {
                        VStack(spacing: LoopSpacing.sm) {
                            LoopDetailRow(label: "Email", value: payload.customer.email ?? "Not recorded")
                            LoopDivider()
                            LoopDetailRow(label: "Phone", value: payload.customer.phone ?? "Not recorded")
                            LoopDivider()
                            LoopDetailRow(label: "Since", value: LoopDate.medium(payload.customer.createdAt))
                        }
                    }

                    if let note = payload.customer.note {
                        LoopDetailSection(title: "Note") {
                            Text(note)
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !payload.opportunities.isEmpty {
                        VStack(alignment: .leading, spacing: LoopSpacing.md) {
                            LoopSectionHeader(title: "Opportunities", count: payload.opportunities.count)
                            LoopRowGroup(items: payload.opportunities) { opportunity in
                                LoopNavigationRow {
                                    router.push(.opportunity(opportunity.id))
                                } content: {
                                    OpportunityRow(opportunity: opportunity)
                                }
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

                    VStack(spacing: LoopSpacing.md) {
                        LoopButton(title: "New quote", symbol: "doc.badge.plus") {
                            router.present(.newQuote(customerID: payload.customer.id))
                        }
                        LoopSecondaryButton(title: "Edit customer", symbol: "pencil") {
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
        .navigationTitle("Customer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing, onDismiss: { Task { await load() } }) {
            CustomerEditorView(customer: state.value?.customer)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            let customer = try await loop.customerService.customer(id: customerID, accountID: accountID)
            async let opportunities = loop.opportunityService.opportunities(accountID: accountID)
            async let quotes = loop.quoteService.quotes(accountID: accountID)
            async let earnings = loop.businessService.earnings(accountID: accountID)
            let (allOpportunities, allQuotes, allEarnings) = try await (opportunities, quotes, earnings)
            state = .loaded(
                Payload(
                    customer: customer,
                    opportunities: allOpportunities.filter { $0.customerID == customerID },
                    quotes: allQuotes.filter { $0.customerID == customerID },
                    earnings: allEarnings.filter { $0.customerID == customerID }
                )
            )
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct CustomerEditorView: View {
    let customer: Customer?

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var company = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var note = ""
    @State private var isSaving = false
    @State private var error: LoopError?

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private var emailError: String? {
        guard !email.isEmpty else { return nil }
        return email.contains("@") && email.contains(".") ? nil : "Enter a valid email address"
    }

    var body: some View {
        LoopEditorScaffold(
            title: customer == nil ? "New customer" : "Edit customer",
            isSaveEnabled: isValid && emailError == nil && !isSaving,
            onCancel: { dismiss() },
            onSave: { Task { await save() } }
        ) {
            LoopTextField(label: "Name", text: $name, placeholder: "Priya Raman", capitalization: .words, contentType: .name, isRequired: true)
            LoopTextField(label: "Company", text: $company, placeholder: "Beacon Coffee", capitalization: .words, contentType: .organizationName)
            LoopTextField(
                label: "Email",
                text: $email,
                placeholder: "priya@beaconcoffee.co",
                keyboard: .emailAddress,
                capitalization: .never,
                contentType: .emailAddress,
                errorMessage: emailError
            )
            LoopTextField(label: "Phone", text: $phone, placeholder: "(512) 555-0192", keyboard: .phonePad, contentType: .telephoneNumber)
            LoopTextEditor(label: "Notes", text: $note)

            if let error {
                Text(error.message)
                    .font(LoopFont.footnote)
                    .foregroundStyle(LoopColor.critical)
            }
        }
        .onAppear {
            guard let customer else { return }
            name = customer.name
            company = customer.company ?? ""
            email = customer.email ?? ""
            phone = customer.phone ?? ""
            note = customer.note ?? ""
        }
    }

    private func save() async {
        guard let accountID = appState.activeAccountID else { return }
        isSaving = true
        defer { isSaving = false }
        let record = Customer(
            id: customer?.id ?? UUID(),
            accountID: accountID,
            name: name.trimmingCharacters(in: .whitespaces),
            company: company.isEmpty ? nil : company,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            note: note.isEmpty ? nil : note,
            createdAt: customer?.createdAt ?? Date(),
            isArchived: false
        )
        do {
            _ = try await loop.customerService.save(customer: record)
            LoopHaptics.success()
            dismiss()
        } catch {
            LoopHaptics.error()
            self.error = LoopError.map(error)
        }
    }
}
