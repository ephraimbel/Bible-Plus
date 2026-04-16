import SwiftUI
import WidgetKit

struct GreetingWidgetEntryView: View {
    let entry: GreetingWidgetEntry
    @Environment(\.widgetFamily) var family

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

            VStack(spacing: 6) {
                Spacer()

                // Time icon
                Image(systemName: entry.timeIcon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)

                // Greeting + name on one line
                Text("\(entry.greeting), \(entry.firstName)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 1)

                Spacer()

                // Encouragement — fully visible
                Text(entry.encouragement)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "bibleplus://"))
    }

    // MARK: - Accessory Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Row 1: Time icon + greeting
            HStack(spacing: 4) {
                Image(systemName: entry.timeIcon)
                    .font(.system(size: 11, weight: .semibold))

                Text("\(entry.greeting), \(entry.firstName)")
                    .font(.system(size: 12, weight: .semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            // Row 2: Encouragement — fully visible
            Text(entry.encouragement)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .minimumScaleFactor(0.6)
        }
        .widgetURL(URL(string: "bibleplus://"))
    }
}
