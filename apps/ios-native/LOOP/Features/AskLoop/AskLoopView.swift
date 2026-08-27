import SwiftUI
import Observation

@MainActor
@Observable
final class AskLoopViewModel {
    private(set) var messages: [AskLoopMessage] = []
    private(set) var isSending = false
    var draft: String = ""

    private let service: any AskLoopService
    private let accountID: UUID
    private var lastUserMessage: String?

    init(service: any AskLoopService, accountID: UUID) {
        self.service = service
        self.accountID = accountID
    }

    var isLive: Bool { service.isLiveIntelligenceAvailable }
    var hasConversation: Bool { !messages.isEmpty }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    func send(_ text: String? = nil) async {
        let content = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isSending else { return }
        draft = ""
        lastUserMessage = content
        messages.append(AskLoopMessage(role: .user, text: content))
        await deliver(content)
    }

    func retry() async {
        guard let lastUserMessage else { return }
        messages.removeAll { if case .failed = $0.deliveryState { return true } else { return false } }
        await deliver(lastUserMessage)
    }

    private func deliver(_ content: String) async {
        isSending = true
        defer { isSending = false }
        do {
            let response = try await service.send(message: content, accountID: accountID)
            messages.append(
                AskLoopMessage(
                    role: .loop,
                    text: response.text,
                    referencedDestinations: response.references
                )
            )
            LoopHaptics.impact(.light)
        } catch {
            let mapped = LoopError.map(error)
            messages.append(
                AskLoopMessage(role: .loop, text: mapped.message, deliveryState: .failed(mapped))
            )
            LoopHaptics.warning()
        }
    }

    func clear() {
        messages.removeAll()
        lastUserMessage = nil
    }
}

/// LOOP's intelligence layer — calm, contextual, grounded in the user's records.
struct AskLoopView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var viewModel: AskLoopViewModel?
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let viewModel {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                            if viewModel.hasConversation {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message) { reference in
                                        router.open(reference.source)
                                    } onRetry: {
                                        Task { await viewModel.retry() }
                                    }
                                    .id(message.id)
                                }
                                if viewModel.isSending { ThinkingIndicator() }
                            } else {
                                landing(viewModel)
                            }
                        }
                        .loopGutter()
                        .padding(.vertical, LoopSpacing.lg)
                        .padding(.bottom, LoopSpacing.xl)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        guard let last = viewModel.messages.last else { return }
                        withAnimation(LoopMotion.standard) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                composer(viewModel)
            } else {
                LoopLoadingState(rows: 2).loopGutter()
                Spacer()
            }
        }
        .background(LoopColor.canvas)
        .navigationTitle("Ask LOOP")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel?.hasConversation == true {
                    Button("Clear") { viewModel?.clear() }
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(LoopColor.inkSecondary)
                }
            }
        }
        .task {
            guard viewModel == nil, let accountID = appState.activeAccountID else { return }
            viewModel = AskLoopViewModel(service: loop.askLoopService, accountID: accountID)
        }
    }

    // MARK: - Landing

    private func landing(_ viewModel: AskLoopViewModel) -> some View {
        VStack(alignment: .leading, spacing: LoopSpacing.xl) {
            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                LoopMark(size: 44)
                Text("Ask LOOP")
                    .font(LoopFont.display(32, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                Text("LOOP can read your own records — deadlines, refunds, items, leads and quotes — and answer questions about them.")
                    .font(LoopFont.body)
                    .foregroundStyle(LoopColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, LoopSpacing.md)

            if !viewModel.isLive {
                LoopCard(tint: LoopColor.infoSoft) {
                    HStack(alignment: .top, spacing: LoopSpacing.md) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(LoopColor.info)
                        Text("LOOP's intelligence service isn't connected on this build. Answers below are generated on-device from your sample records — they aren't live AI.")
                            .font(LoopFont.caption)
                            .foregroundStyle(LoopColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                LoopEyebrow(text: "Try asking")
                VStack(spacing: LoopSpacing.sm) {
                    ForEach(AskLoopSuggestion.starters) { suggestion in
                        Button {
                            Task { await viewModel.send(suggestion.text) }
                        } label: {
                            HStack(spacing: LoopSpacing.md) {
                                Image(systemName: suggestion.symbolName)
                                    .font(.system(size: LoopIconSize.md, weight: .medium))
                                    .foregroundStyle(LoopColor.accent)
                                    .frame(width: 24)
                                Text(suggestion.text)
                                    .font(LoopFont.callout)
                                    .foregroundStyle(LoopColor.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, LoopSpacing.lg)
                            .padding(.vertical, LoopSpacing.md)
                            .frame(minHeight: 48)
                            .background(LoopColor.surface, in: .rect(cornerRadius: LoopRadius.md))
                            .overlay {
                                RoundedRectangle(cornerRadius: LoopRadius.md)
                                    .strokeBorder(LoopColor.hairline, lineWidth: 1)
                            }
                        }
                        .buttonStyle(LoopPressStyle())
                    }
                }
            }
        }
    }

    // MARK: - Composer

    private func composer(_ viewModel: AskLoopViewModel) -> some View {
        @Bindable var viewModel = viewModel

        return VStack(spacing: 0) {
            LoopDivider()
            HStack(alignment: .bottom, spacing: LoopSpacing.sm) {
                TextField("Ask about your LOOP…", text: $viewModel.draft, axis: .vertical)
                    .font(LoopFont.body)
                    .foregroundStyle(LoopColor.ink)
                    .lineLimit(1...5)
                    .focused($isComposerFocused)
                    .padding(.horizontal, LoopSpacing.md)
                    .padding(.vertical, LoopSpacing.sm)
                    .frame(minHeight: 44)
                    .background(LoopColor.surfaceSunken, in: .rect(cornerRadius: LoopRadius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: LoopRadius.lg)
                            .strokeBorder(LoopColor.hairline, lineWidth: 1)
                    }
                    .submitLabel(.send)

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 44, height: 44)
                        .background(
                            viewModel.canSend ? LoopColor.accent : LoopColor.inkTertiary,
                            in: .circle
                        )
                }
                .buttonStyle(LoopPressStyle())
                .disabled(!viewModel.canSend)
                .accessibilityLabel("Send question")
            }
            .padding(.horizontal, LoopSpacing.lg)
            .padding(.vertical, LoopSpacing.sm)
            .background(LoopColor.surface)
        }
    }
}

private struct MessageBubble: View {
    let message: AskLoopMessage
    let onReference: (AskLoopReference) -> Void
    let onRetry: () -> Void

    private var isFailed: Bool {
        if case .failed = message.deliveryState { return true }
        return false
    }

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: LoopSpacing.sm) {
            HStack {
                if message.role == .user { Spacer(minLength: LoopSpacing.xxl) }
                Text(message.text)
                    .font(LoopFont.body)
                    .foregroundStyle(message.role == .user ? Color.white : LoopColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, LoopSpacing.lg)
                    .padding(.vertical, LoopSpacing.md)
                    .background(
                        message.role == .user
                            ? AnyShapeStyle(LoopColor.ink)
                            : AnyShapeStyle(isFailed ? LoopColor.criticalSoft : LoopColor.surface),
                        in: .rect(cornerRadius: LoopRadius.lg)
                    )
                    .overlay {
                        if message.role == .loop {
                            RoundedRectangle(cornerRadius: LoopRadius.lg)
                                .strokeBorder(LoopColor.hairline, lineWidth: 1)
                        }
                    }
                if message.role == .loop { Spacer(minLength: LoopSpacing.xxl) }
            }

            if !message.referencedDestinations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LoopSpacing.sm) {
                        ForEach(message.referencedDestinations) { reference in
                            Button {
                                onReference(reference)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(reference.label)
                                        .lineLimit(1)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(LoopColor.accent)
                                .padding(.horizontal, LoopSpacing.md)
                                .frame(minHeight: 36)
                                .background(LoopColor.accentSoft, in: .capsule)
                            }
                            .buttonStyle(LoopPressStyle())
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            if isFailed {
                Button("Try again", systemImage: "arrow.clockwise", action: onRetry)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(LoopColor.accent)
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message.role == .user ? "You asked" : "LOOP answered")
    }
}

private struct ThinkingIndicator: View {
    @State private var phase = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(LoopColor.inkTertiary)
                    .frame(width: 6, height: 6)
                    .opacity(reduceMotion ? 0.6 : (phase == index ? 1 : 0.3))
            }
        }
        .padding(.horizontal, LoopSpacing.lg)
        .padding(.vertical, LoopSpacing.md)
        .background(LoopColor.surface, in: .capsule)
        .overlay { Capsule().strokeBorder(LoopColor.hairline, lineWidth: 1) }
        .onAppear {
            guard !reduceMotion else { return }
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { timer in
                Task { @MainActor in
                    phase = (phase + 1) % 3
                    if Task.isCancelled { timer.invalidate() }
                }
            }
        }
        .accessibilityLabel("LOOP is thinking")
    }
}

#Preview {
    NavigationStack { AskLoopView() }
        .environment(\.loop, .preview)
        .environment(AppState(environment: .preview))
        .environment(AppRouter())
}
