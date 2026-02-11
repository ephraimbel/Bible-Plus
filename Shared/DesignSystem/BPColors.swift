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

    // MARK: Light — "Golden Hour"
    static let light = BPColorPalette(
        background: Color(hex: "FAF8F4"),
        surface: Color(hex: "F0E8D8"),
        surfaceElevated: Color(hex: "FFFFFF"),
        accent: Color(hex: "C9A96E"),
        accentSoft: Color(hex: "F5EFE0"),
        textPrimary: Color(hex: "2D2D2D"),
        textSecondary: Color(hex: "7A7A7A"),
        textMuted: Color(hex: "B8B0A0"),
        border: Color(hex: "E0D8C8"),
        error: Color(hex: "C0544F"),
        success: Color(hex: "8BA888")
    )

    // MARK: Dark — "Midnight Study"
    static let dark = BPColorPalette(
        background: Color(hex: "1A1A1A"),
        surface: Color(hex: "242424"),
        surfaceElevated: Color(hex: "2A2A2A"),
        accent: Color(hex: "C9A96E"),
        accentSoft: Color(hex: "3D3428"),
        textPrimary: Color(hex: "E8E4DE"),
        textSecondary: Color(hex: "8A8A8A"),
        textMuted: Color(hex: "5A5A5A"),
        border: Color(hex: "333333"),
        error: Color(hex: "E07070"),
        success: Color(hex: "8BA888")
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
