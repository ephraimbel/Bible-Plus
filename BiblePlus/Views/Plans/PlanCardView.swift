import SwiftUI

struct PlanCardView: View {
    let plan: ReadingPlan
    let progress: UserPlanProgress?
    let isCompleted: Bool
    let isPro: Bool

    @Environment(\.bpPalette) private var palette

    /// Curated artwork for the plan. Prefers the explicit `imageKey` set in
    /// seed JSON (keeps every plan on a distinct, intentional painting); if
    /// that's missing or doesn't resolve, falls back to the tag-overlap engine.
    private var planImage: UIImage? {
        if !plan.imageKey.isEmpty,
           let direct = BiblicalImageService.rawImage(for: plan.imageKey) {
            return direct
        }
        return BiblicalImageService.image(
            for: plan.id,
            context: "\(plan.name) \(plan.planDescription) \(plan.category)"
        )
    }

    private var gradientFallback: LinearGradient {
        let colors = plan.gradientColors.isEmpty
            ? [palette.accent, palette.accent.opacity(0.7)]
            : plan.gradientColors.map { Color(hex: $0) }
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        // New layout: image on top, fades into a clean cream/white text area
        // below — same pattern as the AI chat "Verse for Today" card. The
        // image is no longer the entire background; it's a hero illustration
        // that hands off to legible serif text on the surface color.
        VStack(spacing: 0) {
            // MARK: Hero image area (with bottom fade)
            //
            // The image is a *background* of a Color.clear frame, not a
            // layout-contributing child. With .aspectRatio(.fill) directly
            // in the stack, the image was reporting its intrinsic content
            // size to the layout pass — which made some cards in the All
            // Plans grid wider than their column allowance and pushed past
            // the grid's horizontal padding. Wrapping in Color.clear forces
            // the parent's offered width to drive layout; the image just
            // fills behind it and gets clipped.
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .background {
                        if let image = planImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            gradientFallback
                        }
                    }
                    .clipped()

                // Bottom fade — the painting dissolves into the card's
                // surface color over the bottom ~95pt of the image. Five
                // stops produce a smooth ease-in-out curve so even paintings
                // with bright highlights at the bottom (skies, robes, water)
                // never form a hard band where the gradient meets the image.
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        stops: [
                            .init(color: palette.surfaceElevated.opacity(0.00), location: 0.00),
                            .init(color: palette.surfaceElevated.opacity(0.20), location: 0.30),
                            .init(color: palette.surfaceElevated.opacity(0.55), location: 0.55),
                            .init(color: palette.surfaceElevated.opacity(0.85), location: 0.78),
                            .init(color: palette.surfaceElevated,               location: 1.00),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 95)
                    .allowsHitTesting(false)
                }

                // Top-right status badge (DONE / PRO) sits over the image
                if isCompleted {
                    statusBadge(icon: "checkmark", text: "DONE", tint: .white)
                        .padding(BPSpacing.sm)
                } else if plan.isProOnly && !isPro {
                    statusBadge(icon: "crown.fill", text: "PRO", tint: .white)
                        .padding(BPSpacing.sm)
                }
            }

            // MARK: Text content area (sits on the card's surface color)
            VStack(alignment: .leading, spacing: BPSpacing.xs) {
                Text(plan.name)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: BPSpacing.xs) {
                    Text("\(plan.totalDays) days")
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(palette.textMuted)

                    if !plan.category.isEmpty {
                        Text("\u{00B7}")
                            .foregroundStyle(palette.textMuted.opacity(0.5))
                        Text(plan.category)
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(palette.textMuted)
                            .lineLimit(1)
                    }
                }

                if let progress, !isCompleted {
                    let fraction = progress.completionFraction(totalDays: plan.totalDays)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(palette.accent.opacity(0.15))
                                .frame(height: 3)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [palette.accent, palette.accent.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(6, geo.size.width * fraction), height: 3)
                                .shadow(color: palette.accent.opacity(0.4), radius: 2, y: 0)
                            if fraction > 0 && fraction < 1 {
                                Circle()
                                    .fill(palette.accent)
                                    .frame(width: 7, height: 7)
                                    .shadow(color: palette.accent.opacity(0.6), radius: 3)
                                    .offset(x: max(0, geo.size.width * fraction - 3.5))
                            }
                        }
                    }
                    .frame(height: 7)
                    .padding(.top, BPSpacing.xxs)
                }
            }
            .padding(.horizontal, BPSpacing.md)
            .padding(.top, BPSpacing.xxs)
            .padding(.bottom, BPSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        }
        // Fixed total card height so every card in the All Plans grid is
        // identical regardless of title wrapping, category presence, or
        // progress-bar state. 150 (image) + 95 (text area) = 245.
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 245)
        .background(palette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }

    @ViewBuilder
    private func statusBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: BPSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, BPSpacing.xs)
        .padding(.vertical, BPSpacing.xxs)
        .background(
            Capsule().fill(.black.opacity(0.35))
        )
        .overlay(
            Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5)
        )
    }
}
