import SwiftUI

// MARK: - Brutalist Design System
// A lightweight design system inspired by the app icon:
// Dark textured backgrounds, red/yellow accents, bold typography

public enum BrutalistColors {
    // MARK: - Primary Colors

    /// Pure black - primary dark background
    public static let black = Color(light: .init(white: 0.08), dark: .init(white: 0.02))

    /// Dark grey - elevated surfaces
    public static let surface = Color(light: .init(white: 0.95), dark: .init(white: 0.12))

    /// Medium grey - secondary surfaces
    public static let surfaceSecondary = Color(light: .init(white: 0.88), dark: .init(white: 0.18))

    /// Light grey - borders and dividers
    public static let border = Color(light: .init(white: 0.75), dark: .init(white: 0.25))

    // MARK: - Accent Colors

    /// Tomato red - primary accent from app icon
    public static let red = Color(
        light: .init(red: 0.85, green: 0.18, blue: 0.15),
        dark: .init(red: 0.92, green: 0.25, blue: 0.20)
    )

    /// Warning/timer yellow - from app icon dial
    public static let yellow = Color(
        light: .init(red: 0.95, green: 0.75, blue: 0.10),
        dark: .init(red: 1.0, green: 0.82, blue: 0.20)
    )

    // MARK: - Text Colors

    /// Primary text
    public static let textPrimary = Color(light: .init(white: 0.08), dark: .init(white: 0.98))

    /// Secondary text
    public static let textSecondary = Color(light: .init(white: 0.35), dark: .init(white: 0.65))

    /// Inverted text (for colored backgrounds)
    public static let textInverted = Color(light: .init(white: 0.98), dark: .init(white: 0.02))

    // MARK: - Background

    /// Main app background
    public static let background = Color(light: .init(white: 1.0), dark: .init(white: 0.06))
}

// MARK: - Typography

public enum BrutalistTypography {
    /// App title - bold, condensed
    public static func title(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    /// Large timer display - monospaced for stability
    public static func timer(_ size: CGFloat = 56) -> Font {
        .system(size: size, weight: .heavy, design: .monospaced)
    }

    /// Section headers
    public static let headline: Font = .system(size: 15, weight: .bold, design: .default)

    /// Body text - readable
    public static let body: Font = .system(size: 15, weight: .medium, design: .default)

    /// Secondary/caption text
    public static let caption: Font = .system(size: 13, weight: .medium, design: .default)

    /// Small monospaced text
    public static let mono: Font = .system(size: 12, weight: .semibold, design: .monospaced)
}

// MARK: - Spacing

public enum BrutalistSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

public enum BrutalistRadius {
    /// Sharp corners - brutalist default
    public static let none: CGFloat = 0

    /// Subtle rounding
    public static let sm: CGFloat = 4

    /// Standard rounding
    public static let md: CGFloat = 8

    /// Larger rounding for cards
    public static let lg: CGFloat = 12
}

// MARK: - Color Extension

extension Color {
    init(light: Color.Resolved, dark: Color.Resolved) {
        self.init { traits in
            traits.colorScheme == .dark ? Color(dark) : Color(light)
        }
    }
}

// MARK: - View Modifiers

public struct BrutalistCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    public func body(content: Content) -> some View {
        content
            .background(BrutalistColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BrutalistRadius.md)
                    .stroke(BrutalistColors.border, lineWidth: 1)
            )
    }
}

public struct BrutalistPrimaryButtonStyle: ButtonStyle {
    let isDestructive: Bool

    public init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrutalistTypography.headline)
            .foregroundStyle(BrutalistColors.textInverted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BrutalistSpacing.md)
            .background(isDestructive ? BrutalistColors.red : BrutalistColors.black)
            .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.sm))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

public struct BrutalistSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrutalistTypography.headline)
            .foregroundStyle(BrutalistColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BrutalistSpacing.md)
            .background(BrutalistColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BrutalistRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: BrutalistRadius.sm)
                    .stroke(BrutalistColors.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    public func brutalistCard() -> some View {
        modifier(BrutalistCardModifier())
    }
}
