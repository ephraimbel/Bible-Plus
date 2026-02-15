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
                // Icon in accent circle
                Image(systemName: plan.iconName.isEmpty ? "book.fill" : plan.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(palette.accentSoft)
                    )

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
                            .fill(palette.success.opacity(0.12))
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
                            .fill(palette.accent.opacity(0.12))
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
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.border.opacity(0.3))
                            .frame(height: 3)

                        Capsule()
                            .fill(palette.accent)
                            .frame(
                                width: geo.size.width * progress.completionFraction(totalDays: plan.totalDays),
                                height: 3
                            )
                    }
                }
                .frame(height: 3)
                .padding(.top, 10)
            }
        }
        .padding(14)
        .frame(height: 150)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.15), lineWidth: 1)
        )
    }
}
