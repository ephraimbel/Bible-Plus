import SwiftUI

struct PlanCardView: View {
    let plan: ReadingPlan
    let progress: UserPlanProgress?
    let isCompleted: Bool
    let isPro: Bool

    @Environment(\.bpPalette) private var palette

    private var gradientColors: [Color] {
        plan.gradientColors.map { Color(hex: $0) }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            LinearGradient(
                colors: gradientColors.isEmpty ? [palette.accent, palette.accent.opacity(0.7)] : gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Large faded icon
            Image(systemName: plan.iconName.isEmpty ? "book.fill" : plan.iconName)
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 70, y: -20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // Pro lock overlay
            if plan.isProOnly && !isPro {
                Color.black.opacity(0.25)

                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(12)
            }

            // Completed badge
            if isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(12)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Spacer()

                Text(plan.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text("\(plan.totalDays) DAYS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.85))

                    Text("·")
                        .foregroundStyle(.white.opacity(0.6))

                    Text(plan.category.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.75))
                }

                // Progress bar if active
                if let progress, !isCompleted {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.2))
                                .frame(height: 4)

                            Capsule()
                                .fill(.white)
                                .frame(width: geo.size.width * progress.completionFraction(totalDays: plan.totalDays), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 2)
                }
            }
            .padding(14)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
