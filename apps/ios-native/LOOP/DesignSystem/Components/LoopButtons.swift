import SwiftUI

/// Primary action. Filled ink surface with the LOOP accent reserved for emphasis.
struct LoopButton: View {
    let title: String
    var symbol: String?
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var prominence: Prominence = .accent
    let action: () -> Void

    enum Prominence {
        case accent
        case ink
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: LoopSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: LoopIconSize.md, weight: .semibold))
                }
                Text(title)
                    .font(.system(.body, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Color.white)
            .background(prominence == .accent ? LoopColor.accent : LoopColor.ink)
            .clipShape(.rect(cornerRadius: LoopRadius.md))
            .opacity(isEnabled && !isLoading ? 1 : 0.45)
        }
        .buttonStyle(LoopPressStyle())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isEnabled ? [] : [])
    }
}

/// Secondary action. Outlined, quiet, safe next to a primary button.
struct LoopSecondaryButton: View {
    let title: String
    var symbol: String?
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LoopSpacing.sm) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: LoopIconSize.md, weight: .semibold))
                }
                Text(title)
                    .font(.system(.body, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(LoopColor.ink)
            .background(LoopColor.surface)
            .clipShape(.rect(cornerRadius: LoopRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: LoopRadius.md)
                    .strokeBorder(LoopColor.hairline, lineWidth: 1.2)
            }
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(LoopPressStyle())
        .disabled(!isEnabled)
    }
}

struct LoopDestructiveButton: View {
    let title: String
    var symbol: String = "trash"
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            HStack(spacing: LoopSpacing.sm) {
                Image(systemName: symbol)
                Text(title).font(.system(.body, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(LoopColor.critical)
            .background(LoopColor.criticalSoft)
            .clipShape(.rect(cornerRadius: LoopRadius.md))
        }
        .buttonStyle(LoopPressStyle())
    }
}

/// Compact circular icon button used in toolbars and card corners.
struct LoopIconButton: View {
    let symbol: String
    let label: String
    var tint: Color = LoopColor.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: LoopIconSize.md, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(LoopColor.surface, in: .circle)
                .overlay { Circle().strokeBorder(LoopColor.hairline, lineWidth: 1) }
        }
        .buttonStyle(LoopPressStyle())
        .accessibilityLabel(label)
    }
}

/// Small inline text action ("View all", "Add").
struct LoopInlineAction: View {
    let title: String
    var symbol: String = "chevron.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title).font(.system(.subheadline, weight: .semibold))
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(LoopColor.accent)
            .padding(.vertical, LoopSpacing.sm)
            .contentShape(.rect)
        }
        .buttonStyle(LoopPressStyle())
    }
}
