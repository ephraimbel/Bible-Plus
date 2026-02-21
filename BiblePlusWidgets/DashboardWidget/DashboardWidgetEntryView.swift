import SwiftUI
import WidgetKit

struct DashboardWidgetEntryView: View {
    let entry: DashboardEntry

    var body: some View {
        HStack(spacing: 0) {
            // Streak
            statColumn(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(entry.currentStreak)",
                label: "Streak"
            )

            // Chapters Read
            statColumn(
                icon: "book.fill",
                iconColor: .white,
                value: "\(entry.chaptersRead)",
                label: "Read"
            )

            // Verses Saved
            statColumn(
                icon: "bookmark.fill",
                iconColor: .white,
                value: "\(entry.versesSaved)",
                label: "Saved"
            )

            // Plan Progress
            planColumn
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "bibleplus://progress"))
    }

    private func statColumn(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }

    private var planColumn: some View {
        VStack(spacing: 4) {
            if let planName = entry.planName {
                // Circular progress ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 28, height: 28)

                    Circle()
                        .trim(from: 0, to: entry.planFraction)
                        .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                }

                Text("Day \(entry.planNextDay)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(planName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Text("—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                Text("No Plan")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }
}
