import SwiftUI

struct PlanCardView: View {
    let plan: ReadingPlan
    let progress: UserPlanProgress?
    let isCompleted: Bool
    let isPro: Bool

    @Environment(\.bpPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: Icon + Pro/Complete badge
            HStack {
                // Icon in double-layer ring
                ZStack {
                    Circle()
                        .fill(palette.accent.opacity(0.05))
                        .frame(width: 42, height: 42)
                    Circle()
                        .fill(palette.accent.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: plan.iconName.isEmpty ? "book.fill" : plan.iconName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.accent)
                }

                Spacer()

                if isCompleted {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("DONE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.8)
                    }
                    .foregroundStyle(palette.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(palette.success.opacity(0.1))
                    )
                    .overlay(
                        Capsule()
                            .stroke(palette.success.opacity(0.2), lineWidth: 0.5)
                    )
                } else if plan.isProOnly && !isPro {
                    HStack(spacing: 3) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text("PRO")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.8)
                    }
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(palette.accent.opacity(0.1))
                    )
                    .overlay(
                        Capsule()
                            .stroke(palette.accent.opacity(0.2), lineWidth: 0.5)
                    )
                }
            }

            Spacer()

            // Title
            Text(plan.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Metadata
            HStack(spacing: 6) {
                Text("\(plan.totalDays) days")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textMuted)

                if !plan.category.isEmpty {
                    Text("\u{00B7}")
                        .foregroundStyle(palette.textMuted.opacity(0.5))
                    Text(plan.category)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }
            }
            .padding(.top, 4)

            // Progress bar if active
            if let progress, !isCompleted {
                let fraction = progress.completionFraction(totalDays: plan.totalDays)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.border.opacity(0.15))
                            .frame(height: 3)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(6, geo.size.width * fraction),
                                height: 3
                            )
                            .shadow(color: palette.accent.opacity(0.4), radius: 3, y: 0)

                        // Glow dot at progress tip
                        if fraction > 0 && fraction < 1 {
                            Circle()
                                .fill(palette.accent)
                                .frame(width: 7, height: 7)
                                .shadow(color: palette.accent.opacity(0.5), radius: 4)
                                .offset(x: max(0, geo.size.width * fraction - 3.5))
                        }
                    }
                }
                .frame(height: 7)
                .padding(.top, 8)
            }
        }
        .padding(14)
        .frame(height: 150)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
    }
}
