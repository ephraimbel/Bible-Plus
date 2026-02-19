import SwiftUI
import WidgetKit

struct ActivityGridWidgetEntryView: View {
    let entry: ActivityGridEntry

    // Monday-first weekday labels mapped to Calendar weekday indices
    // Calendar: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    private let weekdays: [(label: String, calendarIndex: Int)] = [
        ("M", 2), ("T", 3), ("W", 4), ("T", 5), ("F", 6), ("S", 7), ("S", 1)
    ]

    var body: some View {
        VStack(spacing: 8) {
            // Top: Streak label
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)

                Text("\(entry.currentStreak)-day streak")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

            Spacer()

            // Center: 7 day circles
            HStack(spacing: 6) {
                ForEach(weekdays, id: \.calendarIndex) { day in
                    let isActive = entry.activeDays.contains(day.calendarIndex)
                    let isToday = isCurrentWeekday(day.calendarIndex)

                    VStack(spacing: 3) {
                        ZStack {
                            Circle()
                                .fill(isActive ? Color.white : Color.white.opacity(0.15))
                                .frame(width: 16, height: 16)

                            if isToday {
                                Circle()
                                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .frame(width: 22, height: 22)

                        Text(day.label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

            Spacer()

            // Bottom: label
            Text("This Week")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
        .padding(12)
        .widgetURL(URL(string: "bibleplus://progress"))
    }

    private func isCurrentWeekday(_ calendarIndex: Int) -> Bool {
        Calendar.current.component(.weekday, from: Date()) == calendarIndex
    }
}
