import SwiftUI

/// Semantic tone shared by every status surface in LOOP.
nonisolated enum LoopTone: Hashable, Sendable {
    case neutral
    case accent
    case positive
    case caution
    case critical
    case info

    var foreground: Color {
        switch self {
        case .neutral: return LoopColor.inkSecondary
        case .accent: return LoopColor.accent
        case .positive: return LoopColor.positive
        case .caution: return LoopColor.caution
        case .critical: return LoopColor.critical
        case .info: return LoopColor.info
        }
    }

    var background: Color {
        switch self {
        case .neutral: return LoopColor.surfaceSunken
        case .accent: return LoopColor.accentSoft
        case .positive: return LoopColor.positiveSoft
        case .caution: return LoopColor.cautionSoft
        case .critical: return LoopColor.criticalSoft
        case .info: return LoopColor.infoSoft
        }
    }
}

/// Status pill. Always renders a glyph as well as colour so status is never
/// communicated by colour alone.
struct LoopStatusBadge: View {
    let title: String
    var tone: LoopTone = .neutral
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(title)
                .font(.system(.caption, weight: .semibold))
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, LoopSpacing.sm)
        .padding(.vertical, 5)
        .background(tone.background, in: .rect(cornerRadius: LoopRadius.xs))
        .accessibilityLabel("Status: \(title)")
    }
}

/// Priority marker for Today. Uses a filled bar + label rather than a colour dot.
struct LoopPriorityBadge: View {
    let priority: ActionPriority

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: priority.symbolName)
                .font(.system(size: 10, weight: .bold))
            Text(priority.label.uppercased())
                .font(LoopFont.eyebrow)
                .kerning(0.6)
        }
        .foregroundStyle(priority.tone.foreground)
        .padding(.horizontal, LoopSpacing.sm)
        .padding(.vertical, 4)
        .background(priority.tone.background, in: .rect(cornerRadius: LoopRadius.xs))
        .accessibilityLabel("Priority: \(priority.label)")
    }
}

/// Deadline chip: "4 days left", "Due today", "Expired yesterday".
struct LoopDeadlineView: View {
    let date: Date
    var compact: Bool = false

    private var days: Int { LoopDate.daysRemaining(until: date) }

    private var tone: LoopTone {
        switch days {
        case ..<0: return .critical
        case 0...2: return .critical
        case 3...6: return .caution
        default: return .neutral
        }
    }

    var body: some View {
        LoopStatusBadge(
            title: LoopDate.deadline(date),
            tone: tone,
            symbol: days < 0 ? "clock.badge.xmark" : "clock"
        )
        .accessibilityLabel(LoopDate.deadline(date) + (compact ? "" : ", \(LoopDate.medium(date))"))
    }
}

/// Small circular glyph used to head list rows and action cards.
struct LoopGlyph: View {
    let symbol: String
    var tone: LoopTone = .neutral
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tone.foreground)
            .frame(width: size, height: size)
            .background(tone.background, in: .rect(cornerRadius: size * 0.32))
            .accessibilityHidden(true)
    }
}
