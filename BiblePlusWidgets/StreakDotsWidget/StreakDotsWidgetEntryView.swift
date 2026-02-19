import SwiftUI
import WidgetKit

struct StreakDotsWidgetEntryView: View {
    let entry: StreakDotsEntry

    // Monday-first weekday labels mapped to Calendar weekday indices
    private let weekdays: [(label: String, calendarIndex: Int)] = [
        ("M", 2), ("T", 3), ("W", 4), ("T", 5), ("F", 6), ("S", 7), ("S", 1)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: Flame + streak text
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))

                Text("\(entry.currentStreak) Day Streak")
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
