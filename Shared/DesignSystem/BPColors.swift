import SwiftUI

// MARK: - Color Palette

struct BPColorPalette {
    let background: Color
    let surface: Color
    let surfaceElevated: Color
    let accent: Color
    let accentSoft: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let border: Color
    let error: Color
    let success: Color
    let jesusWords: Color
    let parchment: Color

    // MARK: Light — "Gallery White" (soft warm canvas, pure white cards)
    //
    // High-end editorial direction. A barely-warm white canvas — just
    // enough tan to take the clinical edge off a pure-white screen —
    // with PURE WHITE cards that pop cleanly on top. Gold accents + the
    // home page's soft gold-tan bottom glow + sepia ink supply the
    // warmth so the UI feels premium, not sterile.
    //
    // Hierarchy:
    //   background      = soft warm white (R-B≈8, a whisper of tan)
    //   surfaceElevated = warm ivory cards (brighter than canvas → they lift,
    //                     but warmer than stark white so they don't read sterile)
    //   surface         = deeper beige for recessed elements inside cards
    //
    // Dark mode is untouched.
    static let light = BPColorPalette(
        background: Color(hex: "FBF8F3"),        // soft warm white — slight tan, not harsh
        surface: Color(hex: "F4EFE6"),           // soft beige — recessed elements, tracks
        surfaceElevated: Color(hex: "FEFBF4"),   // warm ivory — lifts off the canvas, gently warmer than stark white
        accent: Color(hex: "C9A96E"),            // gold — our signature accent
        accentSoft: Color(hex: "F3EBDB"),        // softened gold-cream wash
        textPrimary: Color(hex: "3B2B1D"),       // deep sepia brown — "ink on paper"
        textSecondary: Color(hex: "6B5949"),     // medium warm brown
        textMuted: Color(hex: "9E8D7B"),         // muted warm tan
        border: Color(hex: "EBE4D6"),            // soft warm hairline
        error: Color(hex: "B54A42"),             // warm red
        success: Color(hex: "7D9E7A"),           // warm sage
        jesusWords: Color(hex: "8B342E"),        // deep red
        parchment: Color(hex: "FBF8F3")          // warm paper, matches canvas
    )

    // MARK: Dark — "Midnight Study" (warm matte black)
    static let dark = BPColorPalette(
        background: Color(hex: "2B2A27"),
        surface: Color(hex: "343330"),
        surfaceElevated: Color(hex: "3D3C38"),
        accent: Color(hex: "C9A96E"),
        accentSoft: Color(hex: "3D3428"),
        textPrimary: Color(hex: "ECECEC"),
        textSecondary: Color(hex: "A9A9A6"),
        textMuted: Color(hex: "6B6B68"),
        border: Color(hex: "4A4945"),
        error: Color(hex: "E07070"),
        success: Color(hex: "8BA888"),
        jesusWords: Color(hex: "D4736F"),
        parchment: Color(hex: "2D2B26")
    )

    static func resolve(mode: ColorMode, systemScheme: ColorScheme) -> BPColorPalette {
        switch mode {
        case .light: return .light
        case .dark, .immersive: return .dark
        case .auto: return systemScheme == .dark ? .dark : .light
        }
    }
}

// MARK: - Hex Color Initializer

extension Color {
    /// Linearly blend this color with another by the given amount (0 = self, 1 = other).
    func blend(with other: Color, amount: CGFloat) -> Color {
        let a = UIColor(self)
        let b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = min(max(amount, 0), 1)
        return Color(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t
        )
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Environment Key

private struct BPColorModeKey: EnvironmentKey {
    static let defaultValue: ColorMode = .auto
}

extension EnvironmentValues {
    var bpColorMode: ColorMode {
        get { self[BPColorModeKey.self] }
        set { self[BPColorModeKey.self] = newValue }
    }
}

// MARK: - Convenience Palette Access

private struct BPPaletteKey: EnvironmentKey {
    static let defaultValue: BPColorPalette = .light
}

extension EnvironmentValues {
    var bpPalette: BPColorPalette {
        get { self[BPPaletteKey.self] }
        set { self[BPPaletteKey.self] = newValue }
    }
}
