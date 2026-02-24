import SwiftUI
import WidgetKit

struct StreakDotsWidgetEntryView: View {
    let entry: StreakDotsEntry
    @Environment(\.widgetFamily) var family

    // Monday-first weekday labels mapped to Calendar weekday indices
    private let weekdays: [(label: String, calendarIndex: Int)] = [
        ("M", 2), ("T", 3), ("W", 4), ("T", 5), ("F", 6), ("S", 7), ("S", 1)
    ]

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            rectangularView
        }
    }

    // MARK: - System Small

    private var smallView: some View {
        ZStack {
            WidgetBackgroundView(gradientColors: entry.backgroundGradient)

            VStack(spacing: 8) {
                // Top: Flame + streak
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)

                    Text("\(entry.currentStreak)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

                Text(entry.currentStreak == 1 ? "Day in the Word" : "Days in the Word")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)

                Spacer().frame(height: 4)

                // 7 day dots
                HStack(spacing: 6) {
                    ForEach(weekdays, id: \.calendarIndex) { day in
                        let isActive = entry.activeDays.contains(day.calendarIndex)

                        VStack(spacing: 3) {
                            Circle()
                                .fill(isActive ? Color.white : Color.white.opacity(0.2))
                                .frame(width: 10, height: 10)

                            Text(day.label)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "bibleplus://progress"))
    }

    // MARK: - Accessory Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: Flame + streak text
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))

                Text("\(entry.currentStreak) \(entry.currentStreak == 1 ? "Day" : "Days") in the Word")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }

            // Row 2: 7 day dots
            HStack(spacing: 8) {
                ForEach(weekdays, id: \.calendarIndex) { day in
                    let isActive = entry.activeDays.contains(day.calendarIndex)

                    VStack(spacing: 2) {
                        Circle()
                            .fill(isActive ? Color.primary : Color.primary.opacity(0.2))
                            .frame(width: 8, height: 8)

                        Text(day.label)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .widgetURL(URL(string: "bibleplus://progress"))
    }
}
