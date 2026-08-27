import SwiftUI

// MARK: - Spacing

nonisolated enum LoopSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48

    /// Standard screen gutter.
    static let gutter: CGFloat = 20
}

// MARK: - Radius

nonisolated enum LoopRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let pill: CGFloat = 999
}

// MARK: - Icon sizing

nonisolated enum LoopIconSize {
    static let sm: CGFloat = 14
    static let md: CGFloat = 17
    static let lg: CGFloat = 22
    static let xl: CGFloat = 30
}

// MARK: - Motion

nonisolated enum LoopMotion {
    static let quick: Animation = .spring(response: 0.28, dampingFraction: 0.86)
    static let standard: Animation = .spring(response: 0.42, dampingFraction: 0.88)
    static let gentle: Animation = .easeInOut(duration: 0.35)
    static let settle: Animation = .spring(response: 0.55, dampingFraction: 0.9)
}

// MARK: - Colors

/// LOOP's palette: warm ledger paper and ink, with a single vermilion signal accent.
/// Deliberately restrained — status meaning is carried by shape and label too, never
/// by colour alone.
nonisolated enum LoopColor {
    // Surfaces
    static let canvas = Color.loop(light: 0xF7F4EE, dark: 0x111013)
    static let surface = Color.loop(light: 0xFFFFFF, dark: 0x1B1A1E)
    static let surfaceRaised = Color.loop(light: 0xFFFFFF, dark: 0x232227)
    static let surfaceSunken = Color.loop(light: 0xEFEBE2, dark: 0x0B0A0C)

    // Ink
    static let ink = Color.loop(light: 0x17161A, dark: 0xF4F1EB)
    static let inkSecondary = Color.loop(light: 0x5C5860, dark: 0xA8A3AE)
    static let inkTertiary = Color.loop(light: 0x8B8690, dark: 0x77727E)

    // Lines
    static let hairline = Color.loop(light: 0xE2DCD1, dark: 0x2E2C33)

    // Signal accent
    static let accent = Color.loop(light: 0xD8482A, dark: 0xF2643F)
    static let accentSoft = Color.loop(light: 0xFBE9E2, dark: 0x3A211A)

    // Semantics
    static let positive = Color.loop(light: 0x1F6F52, dark: 0x4FBF92)
    static let positiveSoft = Color.loop(light: 0xE2F0E9, dark: 0x14291F)
    static let caution = Color.loop(light: 0xA5711A, dark: 0xE0AE4C)
    static let cautionSoft = Color.loop(light: 0xF7EDD8, dark: 0x342914)
    static let critical = Color.loop(light: 0xA61B2B, dark: 0xF06A72)
    static let criticalSoft = Color.loop(light: 0xF8E4E4, dark: 0x39191D)
    static let info = Color.loop(light: 0x3C5A6B, dark: 0x8FB3C7)
    static let infoSoft = Color.loop(light: 0xE6EDF1, dark: 0x1D262C)
}

extension Color {
    /// Builds an adaptive colour from light/dark hex values. LOOP keeps tokens in
    /// code so the whole palette can be reviewed in one place.
    static func loop(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

// MARK: - Typography

/// LOOP pairs a serif display face (New York) for headline moments with SF for UI
/// text, and monospaced digits everywhere money appears.
nonisolated enum LoopFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static var screenTitle: Font { display(34, weight: .semibold) }
    static var sectionTitle: Font { display(20, weight: .semibold) }
    static var cardTitle: Font { .system(.headline, design: .default) }

    static var body: Font { .system(.body) }
    static var callout: Font { .system(.callout) }
    static var subheadline: Font { .system(.subheadline) }
    static var footnote: Font { .system(.footnote) }
    static var caption: Font { .system(.caption) }

    /// Uppercased micro-label used for section eyebrows.
    static var eyebrow: Font { .system(.caption2, design: .default).weight(.semibold) }

    static func amount(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

// MARK: - Shadow

nonisolated struct LoopShadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    static let card = LoopShadow(color: .black.opacity(0.05), radius: 12, y: 4)
    static let raised = LoopShadow(color: .black.opacity(0.09), radius: 22, y: 10)
}

extension View {
    func loopShadow(_ shadow: LoopShadow = .card) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }

    /// Standard horizontal screen gutter.
    func loopGutter() -> some View {
        padding(.horizontal, LoopSpacing.gutter)
    }
}
