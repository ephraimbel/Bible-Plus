import SwiftUI

// MARK: - Card Surface
//
// The single shape + elevation spec for peer cards across the app: one corner
// radius, one hairline border, one restrained shadow. Use `.bpCardSurface()`
// instead of hand-rolling RoundedRectangle backgrounds so stacked cards read as
// one deliberate system rather than three slightly different ones. Flatter,
// consistent elevation reads more premium than mixed drop shadows.

/// The app's single card elevation. Kept low and warm — in dark mode it's
/// barely-there by design; in light mode it's a quiet lift, never a hard drop.
enum BPElevation {
    static let cardColor = Color.black.opacity(0.06)
    static let cardRadius: CGFloat = 10
    static let cardYOffset: CGFloat = 4
}

extension View {
    /// Apply the standard card shape, border, and shadow.
    /// - Parameters:
    ///   - palette: the active palette (for surface fill + border tint).
    ///   - filled: when `true`, fills with `surfaceElevated`; pass `false` for
    ///     cards that supply their own background (e.g. a full-bleed image).
    ///   - radius: corner radius — defaults to the large-card token.
    ///   - borderColor: stroke color — defaults to the neutral hairline border.
    ///     Pass a tinted color (e.g. a subtle gold) to mark a primary card.
    ///   - borderWidth: stroke width — defaults to the hairline `0.7`.
    func bpCardSurface(
        _ palette: BPColorPalette,
        filled: Bool = true,
        radius: CGFloat = BPRadius.lg,
        borderColor: Color? = nil,
        borderWidth: CGFloat = 0.7
    ) -> some View {
        modifier(BPCardSurfaceModifier(
            palette: palette, filled: filled, radius: radius,
            borderColor: borderColor, borderWidth: borderWidth
        ))
    }
}

private struct BPCardSurfaceModifier: ViewModifier {
    let palette: BPColorPalette
    let filled: Bool
    let radius: CGFloat
    let borderColor: Color?
    let borderWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                if filled {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(palette.surfaceElevated)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(borderColor ?? palette.border.opacity(0.5), lineWidth: borderWidth)
            )
            .shadow(color: BPElevation.cardColor, radius: BPElevation.cardRadius, y: BPElevation.cardYOffset)
    }
}
