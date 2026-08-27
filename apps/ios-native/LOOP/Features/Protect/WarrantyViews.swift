import SwiftUI

struct WarrantiesView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[Warranty]> = .idle

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 3, retry: { Task { await load() } }) { warranties in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    if warranties.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "shield.lefthalf.filled",
                                title: "No warranties recorded",
                                message: "Add coverage to an item you own and LOOP will remind you before it ends."
                            )
                        }
                    } else {
                        group("Ending soon", warranties.filter { $0.status == .expiring })
                        group("Active", warranties.filter { $0.status == .active })
                        group("Expired", warranties.filter { $0.status == .expired })
                        group("Unknown end date", warranties.filter { $0.status == .unknown })
                    }
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Warranties")
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func group(_ title: String, _ warranties: [Warranty]) -> some View {
        if !warranties.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(title: title, count: warranties.count)
                LoopRowGroup(items: warranties) { warranty in
                    LoopNavigationRow {
                        router.push(.warranty(warranty.id))
                    } content: {
                        LoopListRow(
                            title: warranty.itemName,
                            subtitle: "\(warranty.provider) · \(warranty.kind.label)",
                            symbol: warranty.status.symbolName,
                            tone: warranty.status.tone
                        ) {
                            if let end = warranty.coverageEnd {
                                LoopDeadlineView(date: end, compact: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.warrantyService.warranties(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct WarrantyDetailView: View {
    let warrantyID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<Warranty> = .idle
    @State private var documents: [LoopDocument] = []

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 3, retry: { Task { await load() } }) { warranty in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    LoopCard(padding: LoopSpacing.xl, isRaised: true) {
                        VStack(alignment: .leading, spacing: LoopSpacing.md) {
                            Text(warranty.itemName)
                                .font(LoopFont.display(22, weight: .semibold))
                                .foregroundStyle(LoopColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            LoopStatusBadge(
                                title: warranty.status.label,
                                tone: warranty.status.tone,
                                symbol: warranty.status.symbolName
                            )
                            CoverageBar(warranty: warranty)
                        }
                    }

                    LoopDetailSection(title: "Coverage") {
                        VStack(spacing: LoopSpacing.sm) {
                            LoopDetailRow(label: "Provider", value: warranty.provider)
                            LoopDivider()
                            LoopDetailRow(label: "Type", value: warranty.kind.label)
                            LoopDivider()
                            LoopDetailRow(label: "Starts", value: LoopDate.medium(warranty.coverageStart))
                            LoopDivider()
                            LoopDetailRow(
                                label: "Ends",
                                value: warranty.coverageEnd.map(LoopDate.medium) ?? "Not recorded"
                            )
                            if let reference = warranty.referenceNumber {
                                LoopDivider()
                                LoopDetailRow(label: "Reference", value: reference, isMonospaced: true)
                            }
                        }
                    }

                    if let note = warranty.note {
                        LoopDetailSection(title: "Note") {
                            Text(note)
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    LoopDetailSection(
                        title: "Documents",
                        trailingTitle: "Attach",
                        trailingAction: { router.present(.attachDocument(.warranty(warranty.id))) }
                    ) {
                        if documents.isEmpty {
                            Text("No warranty paperwork attached yet.")
                                .font(LoopFont.footnote)
                                .foregroundStyle(LoopColor.inkSecondary)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                                    DocumentRow(document: document)
                                    if index < documents.count - 1 { LoopDivider() }
                                }
                            }
                        }
                    }

                    if let itemID = warranty.ownedItemID {
                        VStack(spacing: LoopSpacing.md) {
                            LoopSecondaryButton(title: "Edit warranty", symbol: "pencil") {
                                router.present(.editWarranty(ownedItemID: itemID, warrantyID: warranty.id))
                            }
                            LoopSecondaryButton(title: "View item", symbol: "shippingbox") {
                                router.push(.ownedItem(itemID))
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
        .navigationTitle("Warranty")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.warrantyService.warranty(id: warrantyID, accountID: accountID))
            documents = try await loop.documentService.documents(
                for: .warranty(warrantyID), accountID: accountID
            )
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct CoverageBar: View {
    let warranty: Warranty

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(LoopColor.surfaceSunken)
                    Capsule()
                        .fill(warranty.status.tone.foreground)
                        .frame(width: max(4, proxy.size.width * warranty.coverageProgress))
                }
            }
            .frame(height: 6)
            HStack {
                Text(LoopDate.short(warranty.coverageStart))
                Spacer()
                if let end = warranty.coverageEnd {
                    Text(LoopDate.deadline(end))
                        .foregroundStyle(warranty.status.tone.foreground)
                } else {
                    Text("End date unknown")
                }
            }
            .font(LoopFont.caption)
            .foregroundStyle(LoopColor.inkTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            warranty.coverageEnd.map { "Coverage ends \(LoopDate.medium($0))" } ?? "Coverage end unknown"
        )
    }
}

/// Create or edit a warranty for an owned item.
struct WarrantyEditorView: View {
    let ownedItemID: UUID
    let warrantyID: UUID?

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var itemName: String = ""
    @State private var provider: String = ""
    @State private var kind: WarrantyKind = .manufacturer
    @State private var coverageStart: Date = Date()
    @State private var hasEndDate: Bool = true
    @State private var coverageEnd: Date = LoopDate.adding(days: 365, to: Date())
    @State private var reference: String = ""
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var error: LoopError?

    private var isValid: Bool {
        !itemName.trimmingCharacters(in: .whitespaces).isEmpty
            && !provider.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        LoopEditorScaffold(
            title: warrantyID == nil ? "Add warranty" : "Edit warranty",
            isSaveEnabled: isValid && !isSaving,
            onCancel: { dismiss() },
            onSave: { Task { await save() } }
        ) {
            LoopTextField(label: "Item", text: $itemName, placeholder: "Dyson V12", capitalization: .words, isRequired: true)
            LoopTextField(label: "Provider", text: $provider, placeholder: "Dyson", capitalization: .words, isRequired: true)

            VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                LoopEyebrow(text: "Type")
                Picker("Type", selection: $kind) {
                    ForEach(WarrantyKind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            DatePicker("Coverage starts", selection: $coverageStart, displayedComponents: .date)
                .font(LoopFont.subheadline)

            Toggle("Has an end date", isOn: $hasEndDate)
                .font(LoopFont.subheadline)
            if hasEndDate {
                DatePicker("Coverage ends", selection: $coverageEnd, displayedComponents: .date)
                    .font(LoopFont.subheadline)
            }

            LoopTextField(label: "Reference number", text: $reference, placeholder: "Optional", capitalization: .characters)
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
        if let warrantyID,
           let existing = try? await loop.warrantyService.warranty(id: warrantyID, accountID: accountID) {
            itemName = existing.itemName
            provider = existing.provider
            kind = existing.kind
            coverageStart = existing.coverageStart
            hasEndDate = existing.coverageEnd != nil
            coverageEnd = existing.coverageEnd ?? LoopDate.adding(days: 365, to: existing.coverageStart)
            reference = existing.referenceNumber ?? ""
            note = existing.note ?? ""
        } else if let item = try? await loop.purchaseService.ownedItem(id: ownedItemID, accountID: accountID) {
            itemName = item.name
            provider = item.merchant
            coverageStart = item.purchasedAt
            coverageEnd = LoopDate.adding(days: 365, to: item.purchasedAt)
        }
    }

    private func save() async {
        guard let accountID = appState.activeAccountID else { return }
        isSaving = true
        defer { isSaving = false }
        let warranty = Warranty(
            id: warrantyID ?? UUID(),
            accountID: accountID,
            ownedItemID: ownedItemID,
            itemName: itemName.trimmingCharacters(in: .whitespaces),
            provider: provider.trimmingCharacters(in: .whitespaces),
            kind: kind,
            coverageStart: coverageStart,
            coverageEnd: hasEndDate ? coverageEnd : nil,
            referenceNumber: reference.isEmpty ? nil : reference,
            documentIDs: [],
            note: note.isEmpty ? nil : note
        )
        do {
            _ = try await loop.warrantyService.save(warranty: warranty)
            LoopHaptics.success()
            dismiss()
        } catch {
            LoopHaptics.error()
            self.error = LoopError.map(error)
        }
    }
}
