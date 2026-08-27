import SwiftUI

/// Renders the four async states consistently across every LOOP feature.
struct LoadableView<Value: Sendable, Content: View>: View {
    let state: LoadState<Value>
    var loadingRows: Int = 3
    var retry: (() -> Void)?
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            LoopLoadingState(rows: loadingRows)
                .transition(.opacity)
        case .loaded(let value):
            content(value)
                .transition(.opacity)
        case .failed(let error):
            LoopErrorState(error: error, retry: retry)
                .transition(.opacity)
        }
    }
}

/// Rounded card wrapper for a vertical list of rows with hairline separators.
struct LoopRowGroup<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder var row: (Item) -> Row

    var body: some View {
        LoopCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(item)
                        .padding(.horizontal, LoopSpacing.lg)
                        .padding(.vertical, LoopSpacing.md)
                    if index < items.count - 1 {
                        LoopDivider(inset: LoopSpacing.lg)
                    }
                }
            }
        }
    }
}

/// A tappable row inside a `LoopRowGroup`.
struct LoopNavigationRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        Button(action: action) { content }
            .buttonStyle(LoopPressStyle())
    }
}

/// Sheet header with cancel/save, used by every editor.
struct LoopSheetHeader: View {
    let title: String
    var saveTitle: String = "Save"
    var isSaveEnabled: Bool = true
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(LoopFont.body)
                .foregroundStyle(LoopColor.inkSecondary)
                .frame(minWidth: 60, minHeight: 44, alignment: .leading)
            Spacer()
            Text(title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(LoopColor.ink)
                .lineLimit(1)
            Spacer()
            Button(saveTitle, action: onSave)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(isSaveEnabled ? LoopColor.accent : LoopColor.inkTertiary)
                .disabled(!isSaveEnabled)
                .frame(minWidth: 60, minHeight: 44, alignment: .trailing)
        }
        .padding(.horizontal, LoopSpacing.lg)
        .padding(.top, LoopSpacing.md)
        .padding(.bottom, LoopSpacing.sm)
        .background(LoopColor.surface)
        .overlay(alignment: .bottom) { LoopDivider() }
    }
}

/// Standard editor scaffold: header + scrolling form on LOOP's canvas.
struct LoopEditorScaffold<Content: View>: View {
    let title: String
    var saveTitle: String = "Save"
    var isSaveEnabled: Bool = true
    let onCancel: () -> Void
    let onSave: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            LoopSheetHeader(
                title: title,
                saveTitle: saveTitle,
                isSaveEnabled: isSaveEnabled,
                onCancel: onCancel,
                onSave: onSave
            )
            ScrollView {
                VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                    content
                }
                .padding(LoopSpacing.lg)
                .padding(.bottom, LoopSpacing.xxl)
            }
            .background(LoopColor.canvas)
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDragIndicator(.visible)
    }
}

/// Detail-screen section wrapper: eyebrow + card.
struct LoopDetailSection<Content: View>: View {
    let title: String
    var trailingTitle: String?
    var trailingAction: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
            HStack {
                LoopEyebrow(text: title)
                Spacer()
                if let trailingTitle, let trailingAction {
                    LoopInlineAction(title: trailingTitle, action: trailingAction)
                }
            }
            LoopCard { content }
        }
    }
}
