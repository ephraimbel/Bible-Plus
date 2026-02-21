import SwiftUI
import WidgetKit

struct StreakWidgetEntryView: View {
    let entry: StreakWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    // MARK: - System Small

    private var smallView: some View {
        ZStack {
            WidgetBackgroundView(
                gradientColors: entry.backgroundGradient,
                imageData: entry.backgroundImageData
            )

            VStack(spacing: 4) {
                // Faith label
                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 8, weight: .semibold))
                    Text("FAITHFULNESS")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.5)
                }
                .foregroundStyle(.white.opacity(0.55))
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)

                Spacer()

                Image(systemName: entry.hasActivityToday ? "flame.fill" : "flame")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(entry.hasActivityToday ? .orange : .white.opacity(0.7))
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)

                Text("\(entry.currentStreak)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 1)

                Text(entry.currentStreak == 1 ? "Day in the Word" : "Days in the Word")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)

                Text("Best: \(entry.longestStreak)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                    .shadow(color: .black.opacity(0.4), radius: 1, y: 1)

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "bibleplus://progress"))
    }

    // MARK: - Accessory Circular

    private var circularView: some View {
        let fraction: Double = entry.longestStreak > 0
            ? min(Double(entry.currentStreak) / Double(entry.longestStreak), 1.0)
            : 0

        return Gauge(value: fraction) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 10))
        } currentValueLabel: {
            Text("\(entry.currentStreak)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .padding(2)
        .widgetURL(URL(string: "bibleplus://progress"))
    }

    // MARK: - Accessory Rectangular

    private var rectangularView: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.hasActivityToday ? "flame.fill" : "flame")
                .font(.system(size: 20, weight: .medium))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(entry.currentStreak) \(entry.currentStreak == 1 ? "Day" : "Days") in the Word")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("Longest: \(entry.longestStreak)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .widgetURL(URL(string: "bibleplus://progress"))
    }
}
