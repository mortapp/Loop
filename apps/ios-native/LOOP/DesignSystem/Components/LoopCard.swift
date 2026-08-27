import SwiftUI

/// The base LOOP surface. Everything that groups content sits on one of these.
struct LoopCard<Content: View>: View {
    var padding: CGFloat = LoopSpacing.lg
    var tint: Color?
    var isRaised: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint ?? LoopColor.surface)
            .clipShape(.rect(cornerRadius: LoopRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: LoopRadius.lg)
                    .strokeBorder(LoopColor.hairline, lineWidth: 1)
            }
            .loopShadow(isRaised ? .raised : .card)
    }
}

/// Tappable variant that keeps the whole card as one accessibility element.
struct LoopCardButton<Content: View>: View {
    let action: () -> Void
    var padding: CGFloat = LoopSpacing.lg
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        Button(action: action) {
            LoopCard(padding: padding, tint: tint) { content }
        }
        .buttonStyle(LoopPressStyle())
    }
}

/// Subtle scale + opacity feedback used across LOOP's tappable surfaces.
struct LoopPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.982 : 1))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(LoopMotion.quick, value: configuration.isPressed)
    }
}

/// A metric tile: label, large monospaced value, optional trailing detail.
struct LoopMetricCard: View {
    let label: String
    let value: String
    var detail: String?
    var symbol: String?
    var valueColor: Color = LoopColor.ink
    var accessibilityValue: String?

    var body: some View {
        LoopCard(padding: LoopSpacing.lg) {
            VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                HStack(spacing: LoopSpacing.xs) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: LoopIconSize.sm, weight: .semibold))
                            .foregroundStyle(LoopColor.inkTertiary)
                    }
                    Text(label.uppercased())
                        .font(LoopFont.eyebrow)
                        .kerning(0.7)
                        .foregroundStyle(LoopColor.inkTertiary)
                }
                Text(value)
                    .font(LoopFont.amount(24))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let detail {
                    Text(detail)
                        .font(LoopFont.footnote)
                        .foregroundStyle(LoopColor.inkSecondary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue ?? value + (detail.map { ", \($0)" } ?? ""))
    }
}
