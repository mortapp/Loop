import SwiftUI

/// Every receipt, invoice and piece of evidence in the account.
struct DocumentsView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState

    @State private var state: LoadState<[LoopDocument]> = .idle
    @State private var typeFilter: DocumentFilter = .all

    nonisolated enum DocumentFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
        case all, receipt, warranty, evidence

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "All"
            case .receipt: return "Receipts"
            case .warranty: return "Warranties"
            case .evidence: return "Evidence"
            }
        }

        func matches(_ document: LoopDocument) -> Bool {
            switch self {
            case .all: return true
            case .receipt: return document.type == .receipt || document.type == .invoice
            case .warranty: return document.type == .warranty
            case .evidence:
                return [.returnConfirmation, .shippingEvidence, .refundConfirmation].contains(document.type)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                LoopFilterChips(values: DocumentFilter.allCases, selection: $typeFilter) { $0.label }
                    .padding(.horizontal, -LoopSpacing.gutter)

                LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { documents in
                    let visible = documents.filter { typeFilter.matches($0) }
                    if visible.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "doc.on.doc",
                                title: "No documents here",
                                message: "Receipts and evidence you attach to purchases, returns and warranties collect in one place."
                            )
                        }
                    } else {
                        LoopRowGroup(items: visible) { document in
                            DocumentRow(document: document)
                        }
                    }
                }
            }
            .loopGutter()
            .padding(.vertical, LoopSpacing.md)
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("Documents")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.documentService.documents(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

/// One attached document, with an honest open action.
struct DocumentRow: View {
    let document: LoopDocument

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    @State private var openError: LoopError?

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.xs) {
            Button {
                Task { await open() }
            } label: {
                HStack(spacing: LoopSpacing.md) {
                    LoopGlyph(symbol: document.type.symbolName, tone: .info, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.filename)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(LoopColor.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text([
                            document.type.label,
                            document.sizeDescription,
                            LoopDate.medium(document.createdAt)
                        ].compactMap { $0 }.joined(separator: " · "))
                            .font(LoopFont.caption)
                            .foregroundStyle(LoopColor.inkSecondary)
                    }
                    Spacer(minLength: LoopSpacing.sm)
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LoopColor.inkTertiary)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(LoopPressStyle())

            if let openError {
                Text(openError.message)
                    .font(LoopFont.caption)
                    .foregroundStyle(LoopColor.caution)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func open() async {
        guard let accountID = appState.activeAccountID else { return }
        openError = nil
        do {
            let url = try await loop.documentService.downloadURL(for: document.id, accountID: accountID)
            openURL(url)
        } catch {
            LoopHaptics.warning()
            withAnimation(LoopMotion.quick) { openError = LoopError.map(error) }
        }
    }
}

/// Records document metadata against a LOOP record.
struct AttachDocumentView: View {
    let target: DocumentAttachmentTarget

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var filename: String = ""
    @State private var type: DocumentType = .receipt
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var error: LoopError?

    private var isValid: Bool { !filename.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        LoopEditorScaffold(
            title: "Attach document",
            saveTitle: "Attach",
            isSaveEnabled: isValid && !isSaving,
            onCancel: { dismiss() },
            onSave: { Task { await save() } }
        ) {
            Text("Record what this document is and where it lives, so LOOP can point you at it when a return or claim needs proof.")
                .font(LoopFont.subheadline)
                .foregroundStyle(LoopColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            LoopTextField(
                label: "File name",
                text: $filename,
                placeholder: "best-buy-receipt.pdf",
                capitalization: .never,
                isRequired: true
            )

            VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                LoopEyebrow(text: "Type")
                Picker("Type", selection: $type) {
                    ForEach(DocumentType.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(LoopColor.accent)
            }

            LoopTextEditor(label: "Note", text: $note, minHeight: 80)

            LoopCard(tint: LoopColor.infoSoft) {
                Text("File upload needs LOOP's document storage, which isn't connected on this build. LOOP stores the record now and links the file once storage is configured.")
                    .font(LoopFont.caption)
                    .foregroundStyle(LoopColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error {
                Text(error.message)
                    .font(LoopFont.footnote)
                    .foregroundStyle(LoopColor.critical)
            }
        }
    }

    private func save() async {
        guard let accountID = appState.activeAccountID else { return }
        isSaving = true
        defer { isSaving = false }
        let document = LoopDocument(
            id: UUID(),
            accountID: accountID,
            type: type,
            filename: filename.trimmingCharacters(in: .whitespaces),
            byteSize: nil,
            createdAt: Date(),
            target: target,
            storagePath: nil,
            note: note.isEmpty ? nil : note
        )
        do {
            _ = try await loop.documentService.attach(document: document)
            LoopHaptics.success()
            dismiss()
        } catch {
            LoopHaptics.error()
            self.error = LoopError.map(error)
        }
    }
}
