import SwiftUI

/// Generic async view state used by every LOOP feature.
nonisolated enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(LoopError)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var error: LoopError? {
        if case .failed(let error) = self { return error }
        return nil
    }
}

/// Intentional empty state — always explains what will appear here and why.
struct LoopEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: LoopSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(LoopColor.inkTertiary)
                .frame(width: 64, height: 64)
                .background(LoopColor.surfaceSunken, in: .circle)
            VStack(spacing: LoopSpacing.xs) {
                Text(title)
                    .font(LoopFont.cardTitle)
                    .foregroundStyle(LoopColor.ink)
                Text(message)
                    .font(LoopFont.subheadline)
                    .foregroundStyle(LoopColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                LoopSecondaryButton(title: actionTitle, symbol: "plus", action: action)
                    .frame(maxWidth: 260)
                    .padding(.top, LoopSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LoopSpacing.xxl)
        .padding(.horizontal, LoopSpacing.lg)
        .accessibilityElement(children: .combine)
    }
}

/// Error state with a retry affordance for retryable failures.
struct LoopErrorState: View {
    let error: LoopError
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: LoopSpacing.md) {
            Image(systemName: error.symbolName)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(LoopColor.critical)
                .frame(width: 64, height: 64)
                .background(LoopColor.criticalSoft, in: .circle)
            VStack(spacing: LoopSpacing.xs) {
                Text(error.title)
                    .font(LoopFont.cardTitle)
                    .foregroundStyle(LoopColor.ink)
                Text(error.message)
                    .font(LoopFont.subheadline)
                    .foregroundStyle(LoopColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let retry, error.isRetryable {
                LoopSecondaryButton(title: "Try again", symbol: "arrow.clockwise", action: retry)
                    .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LoopSpacing.xxl)
        .padding(.horizontal, LoopSpacing.lg)
        .accessibilityElement(children: .combine)
    }
}

/// Shimmer-free, calm skeleton placeholder.
struct LoopSkeleton: View {
    var height: CGFloat = 16
    var width: CGFloat?
    var cornerRadius: CGFloat = LoopRadius.xs

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LoopColor.surfaceSunken)
            .frame(width: width, height: height)
            .opacity(isPulsing ? 0.55 : 1)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
            .accessibilityHidden(true)
    }
}

/// Loading placeholder shaped like the content it replaces.
struct LoopLoadingState: View {
    var rows: Int = 3

    var body: some View {
        VStack(spacing: LoopSpacing.md) {
            ForEach(0..<rows, id: \.self) { _ in
                LoopCard {
                    HStack(spacing: LoopSpacing.md) {
                        LoopSkeleton(height: 38, width: 38, cornerRadius: 12)
                        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                            LoopSkeleton(height: 13, width: 150)
                            LoopSkeleton(height: 11, width: 95)
                        }
                        Spacer()
                    }
                }
            }
        }
        .accessibilityLabel("Loading")
    }
}
