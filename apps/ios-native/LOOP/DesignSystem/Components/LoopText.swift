import SwiftUI

/// Money display with monospaced digits, sign handling and a VoiceOver-safe value.
struct LoopMoneyText: View {
    let amount: MoneyAmount
    var size: CGFloat = 17
    var weight: Font.Weight = .semibold
    var showsSign: Bool = false
    var tone: Tone = .automatic

    enum Tone {
        case automatic
        case neutral
        case positive
        case negative
        case muted
    }

    private var color: Color {
        switch tone {
        case .neutral: return LoopColor.ink
        case .positive: return LoopColor.positive
        case .negative: return LoopColor.ink
        case .muted: return LoopColor.inkSecondary
        case .automatic:
            if amount.isPositive && showsSign { return LoopColor.positive }
            return LoopColor.ink
        }
    }

    var body: some View {
        Text(showsSign ? MoneyFormatter.signedString(amount) : MoneyFormatter.string(amount))
            .font(LoopFont.amount(size, weight: weight))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityLabel(MoneyFormatter.accessibleString(amount, showsSign: showsSign))
    }
}

/// Section heading with optional eyebrow count and trailing action.
struct LoopSectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var count: Int?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: LoopSpacing.sm) {
                    Text(title)
                        .font(LoopFont.sectionTitle)
                        .foregroundStyle(LoopColor.ink)
                    if let count, count > 0 {
                        Text("\(count)")
                            .font(LoopFont.caption.weight(.semibold))
                            .foregroundStyle(LoopColor.inkSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(LoopColor.surfaceSunken, in: .capsule)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(LoopFont.footnote)
                        .foregroundStyle(LoopColor.inkSecondary)
                }
            }
            Spacer(minLength: LoopSpacing.sm)
            trailing
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

extension LoopSectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, count: Int? = nil) {
        self.init(title: title, subtitle: subtitle, count: count) { EmptyView() }
    }
}

/// Uppercased micro heading used inside detail cards.
struct LoopEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(LoopFont.eyebrow)
            .kerning(0.8)
            .foregroundStyle(LoopColor.inkTertiary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Label/value line used throughout detail screens.
struct LoopDetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = LoopColor.ink
    var isMonospaced: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: LoopSpacing.md) {
            Text(label)
                .font(LoopFont.subheadline)
                .foregroundStyle(LoopColor.inkSecondary)
            Spacer(minLength: LoopSpacing.sm)
            Text(value)
                .font(isMonospaced
                      ? LoopFont.amount(15, weight: .medium)
                      : .system(.subheadline, weight: .medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Navigable row used for lists of records.
struct LoopListRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tone: LoopTone = .neutral
    var showsChevron: Bool = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: LoopSpacing.md) {
            if let symbol {
                LoopGlyph(symbol: symbol, tone: tone)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(LoopFont.footnote)
                        .foregroundStyle(LoopColor.inkSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: LoopSpacing.sm)
            trailing
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LoopColor.inkTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}

extension LoopListRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        symbol: String? = nil,
        tone: LoopTone = .neutral,
        showsChevron: Bool = true
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            tone: tone,
            showsChevron: showsChevron
        ) { EmptyView() }
    }
}

/// Thin divider matching LOOP's hairline token.
struct LoopDivider: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(LoopColor.hairline)
            .frame(height: 1)
            .padding(.leading, inset)
            .accessibilityHidden(true)
    }
}
