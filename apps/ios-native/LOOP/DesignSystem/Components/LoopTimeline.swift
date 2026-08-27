import SwiftUI

/// A single step in a lifecycle timeline (returns, refunds, sales, quotes).
nonisolated struct LoopTimelineStep: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    var detail: String?
    var date: Date?
    var state: State

    nonisolated enum State: Hashable, Sendable {
        case complete
        case current
        case upcoming
        case failed

        var symbol: String {
            switch self {
            case .complete: return "checkmark"
            case .current: return "circle.fill"
            case .upcoming: return "circle"
            case .failed: return "xmark"
            }
        }

        var tone: LoopTone {
            switch self {
            case .complete: return .positive
            case .current: return .accent
            case .upcoming: return .neutral
            case .failed: return .critical
            }
        }

        var label: String {
            switch self {
            case .complete: return "Completed"
            case .current: return "In progress"
            case .upcoming: return "Not started"
            case .failed: return "Failed"
            }
        }
    }

    init(
        id: String,
        title: String,
        detail: String? = nil,
        date: Date? = nil,
        state: State
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.date = date
        self.state = state
    }
}

/// Vertical connected timeline. Used for return, refund, sale and quote lifecycles.
struct LoopTimeline: View {
    let steps: [LoopTimelineStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: LoopSpacing.md) {
                    VStack(spacing: 0) {
                        marker(for: step)
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(connectorColor(at: index))
                                .frame(width: 2)
                                .frame(minHeight: 26)
                        }
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.system(.subheadline, weight: step.state == .upcoming ? .regular : .semibold))
                            .foregroundStyle(step.state == .upcoming ? LoopColor.inkTertiary : LoopColor.ink)
                        if let detail = step.detail {
                            Text(detail)
                                .font(LoopFont.caption)
                                .foregroundStyle(LoopColor.inkSecondary)
                        }
                        if let date = step.date {
                            Text(LoopDate.medium(date))
                                .font(LoopFont.caption)
                                .foregroundStyle(LoopColor.inkTertiary)
                        }
                    }
                    .padding(.bottom, index < steps.count - 1 ? LoopSpacing.lg : 0)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(step.title). \(step.state.label)")
            }
        }
    }

    private func marker(for step: LoopTimelineStep) -> some View {
        ZStack {
            Circle()
                .fill(step.state == .upcoming ? LoopColor.surfaceSunken : step.state.tone.background)
                .frame(width: 24, height: 24)
            Image(systemName: step.state == .upcoming ? "circle" : step.state.symbol)
                .font(.system(size: step.state == .current ? 8 : 10, weight: .bold))
                .foregroundStyle(step.state == .upcoming ? LoopColor.inkTertiary : step.state.tone.foreground)
        }
    }

    private func connectorColor(at index: Int) -> Color {
        steps[index].state == .complete ? LoopColor.positive.opacity(0.35) : LoopColor.hairline
    }
}
