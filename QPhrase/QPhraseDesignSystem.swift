import SwiftUI

// MARK: - Design System for QPhrase

/// Central design system for consistent styling throughout QPhrase
/// Inspired by Arc/Raycast with clean minimalist aesthetics

// MARK: - Colors
struct QPhraseColors {
    // MARK: Backgrounds (Glassmorphism layers)
    static let backgroundPrimary = Color(.windowBackgroundColor)
    static let backgroundSecondary = Color(.controlBackgroundColor).opacity(0.5)
    static let backgroundTertiary = Color.white.opacity(0.03)

    // MARK: Gradients
    static let subtleGradientStart = Color.white.opacity(0.08)
    static let subtleGradientEnd = Color.white.opacity(0.02)

    // MARK: Status Colors
    static let accentSuccess = Color.green.opacity(0.9)
    static let accentWarning = Color.orange.opacity(0.9)
    static let accentError = Color.red.opacity(0.9)

    // MARK: Text Hierarchy
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary.opacity(0.8)
    static let textTertiary = Color.secondary.opacity(0.5)

    // MARK: Interactive States
    static let hoverBackground = Color.accentColor.opacity(0.12)
    static let selectedBackground = Color.accentColor.opacity(0.18)
    static let pressedBackground = Color.accentColor.opacity(0.25)

    // MARK: Icon Colors (for SF Symbols)
    static let iconBlue = Color.blue
    static let iconPurple = Color.purple
    static let iconOrange = Color.orange
    static let iconPink = Color.pink
    static let iconGreen = Color.green
    static let iconTeal = Color.teal
    static let iconIndigo = Color.indigo
    static let iconYellow = Color.yellow
}

// MARK: - Typography
struct QPhraseTypography {
    // MARK: Headers
    static let headerTitle = Font.system(.headline, design: .rounded, weight: .semibold)
    static let sectionTitle = Font.system(.caption, design: .default, weight: .semibold)

    // MARK: Body
    static let promptName = Font.system(.subheadline, design: .default, weight: .medium)
    static let promptDescription = Font.system(.caption, design: .default, weight: .regular)
    static let bodyText = Font.system(.callout, design: .default, weight: .regular)

    // MARK: UI Elements
    static let badge = Font.system(.caption2, design: .rounded, weight: .medium)
    static let caption = Font.system(.caption, design: .default, weight: .regular)
    static let footnote = Font.system(.caption2, design: .default, weight: .regular)
}

// MARK: - Spacing
struct QPhraseSpacing {
    // MARK: Micro spacing (within elements)
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8

    // MARK: Component spacing
    static let base: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24

    // MARK: Section spacing
    static let sectionGap: CGFloat = 14
    static let cardPadding: CGFloat = 12
    static let edgePadding: CGFloat = 14
}

// MARK: - Depth (Shadows & Blur)
struct QPhraseDepth {
    // MARK: Shadow definitions
    static let cardShadow = Color.black.opacity(0.08)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 2

    static let hoverShadow = Color.black.opacity(0.12)
    static let hoverShadowRadius: CGFloat = 12
    static let hoverShadowY: CGFloat = 4

    static let subtleShadow = Color.black.opacity(0.05)
    static let subtleShadowRadius: CGFloat = 4
    static let subtleShadowY: CGFloat = 1

    // MARK: Glow effects
    static let successGlow = Color.green.opacity(0.2)
    static let accentGlow = Color.accentColor.opacity(0.1)

    // MARK: Corner radius
    static let cardRadius: CGFloat = 10
    static let buttonRadius: CGFloat = 8
    static let badgeRadius: CGFloat = 6
    static let pillRadius: CGFloat = 999
}

// MARK: - Animations
struct QPhraseAnimations {
    // MARK: Primary spring (general UI interactions)
    static let spring = Animation.spring(
        response: 0.35,
        dampingFraction: 0.75,
        blendDuration: 0
    )

    // MARK: Bouncy spring (success/delight moments)
    static let bouncySpring = Animation.spring(
        response: 0.4,
        dampingFraction: 0.6,
        blendDuration: 0
    )

    // MARK: Snappy spring (quick feedback)
    static let snappySpring = Animation.spring(
        response: 0.25,
        dampingFraction: 0.85,
        blendDuration: 0
    )

    // MARK: Ease curves
    static let easeInOut = Animation.easeInOut(duration: 0.2)
    static let easeOut = Animation.easeOut(duration: 0.15)
    static let quick = Animation.easeInOut(duration: 0.1)
}

// MARK: - Reusable Components

/// Circular icon view with gradient background for SF Symbols
struct PromptIconView: View {
    let iconName: String
    let color: Color
    let size: CGFloat

    init(iconName: String, color: Color, size: CGFloat = 32) {
        self.iconName = iconName
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.15), color.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Image(systemName: iconName)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

/// Icon color mapping based on SF Symbol name
struct IconColorMapper {
    static func color(for iconName: String) -> Color {
        switch iconName {
        case "pencil.line", "pencil", "pencil.circle":
            return QPhraseColors.iconBlue
        case "briefcase", "briefcase.fill":
            return QPhraseColors.iconPurple
        case "scissors", "scissors.circle":
            return QPhraseColors.iconOrange
        case "face.smiling", "face.smiling.fill", "smiley":
            return QPhraseColors.iconPink
        case "text.alignleft", "text.aligncenter", "text.justify":
            return QPhraseColors.iconGreen
        case "globe", "globe.americas":
            return QPhraseColors.iconTeal
        case "list.clipboard", "clipboard":
            return QPhraseColors.iconIndigo
        case "envelope", "envelope.fill":
            return QPhraseColors.iconBlue
        case "laptopcomputer", "computer":
            return QPhraseColors.iconPurple
        case "wrench.and.screwdriver", "wrench":
            return QPhraseColors.iconOrange
        case "lightbulb", "lightbulb.fill":
            return QPhraseColors.iconYellow
        case "target":
            return QPhraseColors.iconOrange
        case "chart.bar", "chart.bar.fill":
            return QPhraseColors.iconTeal
        case "magnifyingglass":
            return QPhraseColors.iconBlue
        case "checkmark.circle", "checkmark.circle.fill":
            return QPhraseColors.iconGreen
        case "sparkles", "sparkle":
            return QPhraseColors.iconPink
        default:
            return Color.accentColor
        }
    }
}

/// Glass-morphic card wrapper for consistent styling
struct GlassCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat

    init(padding: CGFloat = QPhraseSpacing.cardPadding, cornerRadius: CGFloat = QPhraseDepth.cardRadius, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.thinMaterial)
                    .shadow(
                        color: QPhraseDepth.cardShadow,
                        radius: QPhraseDepth.cardShadowRadius,
                        y: QPhraseDepth.cardShadowY
                    )
            )
    }
}

// MARK: - Provider Theming
struct ProviderTheme {
    let icon: String  // SF Symbol for small icons
    let logoImage: String  // Asset name for actual logo
    let color: Color
    let displayName: String
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
