import SwiftUI

/// All returns, open first.
struct ReturnsListView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<[ReturnRecord]> = .idle

    private var open: [ReturnRecord] { (state.value ?? []).filter(\.status.isOpen) }
    private var closed: [ReturnRecord] { (state.value ?? []).filter { !$0.status.isOpen } }

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 3, retry: { Task { await load() } }) { records in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    if records.isEmpty {
                        LoopCard {
                            LoopEmptyState(
                                symbol: "arrow.uturn.backward",
                                title: "No returns yet",
                                message: "Start a return from any purchase inside its return window and LOOP will track it all the way to the refund."
                            )
                        }
                    }
                    group("In progress", open)
                    group("Closed", closed)
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Returns")
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func group(_ title: String, _ records: [ReturnRecord]) -> some View {
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(title: title, count: records.count)
                LoopRowGroup(items: records) { record in
                    LoopNavigationRow {
                        router.push(.returnDetail(record.id))
                    } content: {
                        LoopListRow(
                            title: record.itemName,
                            subtitle: "\(record.merchant) · \(record.status.label)",
                            symbol: record.status.symbolName,
                            tone: record.status.tone
                        ) {
                            LoopMoneyText(amount: record.expectedRefund, size: 15, tone: .muted)
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
            state = .loaded(try await loop.returnService.returns(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

/// One return, its timeline, evidence and next step.
struct ReturnDetailView: View {
    let returnID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<ReturnRecord> = .idle
    @State private var documents: [LoopDocument] = []
    @State private var isAdvancing = false

    var body: some View {
        ScrollView {
            LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { record in
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    header(record)

                    LoopDetailSection(title: "Progress") {
                        LoopTimeline(steps: record.timeline)
                    }

                    LoopDetailSection(title: "Details") {
                        VStack(spacing: LoopSpacing.sm) {
                            LoopDetailRow(label: "Merchant", value: record.merchant)
                            LoopDivider()
                            LoopDetailRow(label: "Started", value: LoopDate.medium(record.startedAt))
                            if let deadline = record.deadline {
                                LoopDivider()
                                LoopDetailRow(label: "Window closes", value: LoopDate.medium(deadline))
                            }
                            if let carrier = record.carrier {
                                LoopDivider()
                                LoopDetailRow(label: "Carrier", value: carrier)
                            }
                            if let tracking = record.trackingNumber {
                                LoopDivider()
                                LoopDetailRow(label: "Tracking", value: tracking, isMonospaced: true)
                            }
                            if let reason = record.reason {
                                LoopDivider()
                                VStack(alignment: .leading, spacing: 2) {
                                    LoopEyebrow(text: "Reason")
                                    Text(reason)
                                        .font(LoopFont.subheadline)
                                        .foregroundStyle(LoopColor.inkSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    LoopDetailSection(
                        title: "Evidence",
                        trailingTitle: "Attach",
                        trailingAction: { router.present(.attachDocument(.returnRecord(record.id))) }
                    ) {
                        if documents.isEmpty {
                            Text("Shipping receipts and merchant confirmations protect this refund if it's disputed.")
                                .font(LoopFont.footnote)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                                    DocumentRow(document: document)
                                    if index < documents.count - 1 { LoopDivider() }
                                }
                            }
                        }
                    }

                    actions(record)
                }
                .loopGutter()
                .padding(.vertical, LoopSpacing.md)
                .padding(.bottom, LoopSpacing.xxxl)
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Return")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func header(_ record: ReturnRecord) -> some View {
        LoopCard(padding: LoopSpacing.xl, isRaised: true) {
            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                Text(record.itemName)
                    .font(LoopFont.display(22, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                LoopStatusBadge(
                    title: record.status.label,
                    tone: record.status.tone,
                    symbol: record.status.symbolName
                )
                HStack(alignment: .firstTextBaseline, spacing: LoopSpacing.sm) {
                    Text("Expected refund")
                        .font(LoopFont.footnote)
                        .foregroundStyle(LoopColor.inkSecondary)
                    LoopMoneyText(amount: record.expectedRefund, size: 22)
                }
                .padding(.top, LoopSpacing.xs)
            }
        }
    }

    @ViewBuilder
    private func actions(_ record: ReturnRecord) -> some View {
        VStack(spacing: LoopSpacing.md) {
            if let next = record.status.nextStep {
                LoopButton(
                    title: "Mark as \(next.label.lowercased())",
                    symbol: next.symbolName,
                    isLoading: isAdvancing
                ) {
                    Task { await advance(record, to: next) }
                }
            }
            if let refundID = record.refundID {
                LoopSecondaryButton(title: "View refund", symbol: "arrow.down.left.circle") {
                    router.push(.refund(refundID))
                }
            }
            LoopSecondaryButton(title: "View purchase", symbol: "bag") {
                router.push(.purchase(record.purchaseID))
            }
        }
    }

    private func advance(_ record: ReturnRecord, to status: ReturnStatus) async {
        guard let accountID = appState.activeAccountID else { return }
        isAdvancing = true
        defer { isAdvancing = false }
        do {
            let updated = try await loop.returnService.advance(
                returnID: record.id, to: status, accountID: accountID
            )
            LoopHaptics.success()
            withAnimation(LoopMotion.standard) { state = .loaded(updated) }
        } catch {
            LoopHaptics.error()
            LoopLog.failure(LoopLog.data, "advance return", error)
        }
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            let record = try await loop.returnService.returnRecord(id: returnID, accountID: accountID)
            documents = try await loop.documentService.documents(
                for: .returnRecord(returnID), accountID: accountID
            )
            state = .loaded(record)
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

/// Starts a return from a purchase.
struct StartReturnView: View {
    let purchaseID: UUID

    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var reason: String = ""
    @State private var isSaving = false
    @State private var error: LoopError?

    var body: some View {
        LoopEditorScaffold(
            title: "Start a return",
            saveTitle: "Start",
            isSaveEnabled: !isSaving,
            onCancel: { dismiss() },
            onSave: { Task { await start() } }
        ) {
            Text("LOOP will track this return through shipping, merchant receipt and the refund landing in Money.")
                .font(LoopFont.subheadline)
                .foregroundStyle(LoopColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            LoopTextEditor(
                label: "Reason for return",
                text: $reason,
                placeholder: "Wrong size, damaged in transit, changed my mind…"
            )

            if let error {
                LoopCard(tint: LoopColor.criticalSoft) {
                    Text(error.message)
                        .font(LoopFont.footnote)
                        .foregroundStyle(LoopColor.critical)
                }
            }

            Text("LOOP prepares and tracks the return. It does not contact the merchant for you — you still ship the item yourself.")
                .font(LoopFont.caption)
                .foregroundStyle(LoopColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func start() async {
        guard let accountID = appState.activeAccountID else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let record = try await loop.returnService.startReturn(
                purchaseID: purchaseID, reason: reason, accountID: accountID
            )
            LoopHaptics.success()
            dismiss()
            router.push(.returnDetail(record.id))
        } catch {
            LoopHaptics.error()
            self.error = LoopError.map(error)
        }
    }
}
