import CoreGraphics

/// The app's spacing scale — a strict 4-point grid. Every margin, padding, gap,
/// and inset should use one of these tokens instead of a raw number, so spacing
/// stays consistent and intentional across screens (the Claude / Granola / Haven
/// discipline). If a value you need isn't here, round it to the nearest token —
/// don't reach for an off-grid literal.
///
/// Scale (all multiples of 4):
///   xxs 4 · xs 8 · sm 12 · md 16 · lg 20 · xl 24 · xxl 32 · xxxl 40 · huge 48 · giant 56
enum BPSpacing {
    /// 4 — hairline gaps: icon-to-label, eyebrow-to-title.
    static let xxs: CGFloat = 4
    /// 8 — tight internal spacing, chip padding.
    static let xs: CGFloat = 8
    /// 12 — default gap between stacked elements, card-to-card.
    static let sm: CGFloat = 12
    /// 16 — standard card padding, intra-card section spacing.
    static let md: CGFloat = 16
    /// 20 — generous card padding, screen horizontal margin.
    static let lg: CGFloat = 20
    /// 24 — section spacing, large card padding.
    static let xl: CGFloat = 24
    /// 32 — major section breaks.
    static let xxl: CGFloat = 32
    /// 40 — page-level vertical rhythm.
    static let xxxl: CGFloat = 40
    /// 48 — hero spacing.
    static let huge: CGFloat = 48
    /// 56 — bottom safe inset above a floating tab bar / swipe prompt.
    static let giant: CGFloat = 56
}

/// Corner-radius scale, kept on the 4-point grid and paired with `BPSpacing`.
/// Smaller surfaces take a smaller radius; larger cards a larger one.
enum BPRadius {
    /// 12 — chips, small controls.
    static let sm: CGFloat = 12
    /// 16 — tiles and standard cards.
    static let md: CGFloat = 16
    /// 20 — large feature cards (verse, devotional, plan detail).
    static let lg: CGFloat = 20
    /// 24 — sheets and full-width hero surfaces.
    static let xl: CGFloat = 24
}
