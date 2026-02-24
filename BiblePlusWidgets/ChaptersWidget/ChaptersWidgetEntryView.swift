import SwiftUI
import WidgetKit

struct ChaptersWidgetEntryView: View {
    let entry: ChaptersWidgetEntry
    @Environment(\.widgetFamily) var family

    private var fraction: Double {
        entry.weeklyGoal > 0
            ? min(Double(entry.chaptersThisWeek) / Double(entry.weeklyGoal), 1.0)
            : 0
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            circularView
        }
    }

    // MARK: - System Small

    private var smallView: some View {
        ZStack {
            WidgetBackgroundView(gradientColors: entry.backgroundGradient)

            VStack(spacing: 8) {
                // Label
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("CHAPTERS READ")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.5)
                }
                .foregroundStyle(.white.opacity(0.6))
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 5)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(entry.chaptersThisWeek)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("of \(entry.weeklyGoal)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                Text("This Week")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "bibleplus://progress"))
    }

    // MARK: - Accessory Circular

    private var circularView: some View {
        Gauge(value: fraction) {
            Image(systemName: "book.fill")
                .font(.system(size: 10))
        } currentValueLabel: {
            Text("\(entry.chaptersThisWeek)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(URL(string: "bibleplus://progress"))
    }
}
