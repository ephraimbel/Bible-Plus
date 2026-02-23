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
            WidgetBackgroundView(
                gradientColors: entry.backgroundGradient,
                imageData: entry.backgroundImageData
            )

            VStack(spacing: 8) {
                Spacer()

                // Time icon
                Image(systemName: entry.timeIcon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)

                // Greeting
                Text("\(entry.greeting),")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)

                Text(entry.firstName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 1)

                Spacer()

                // Encouragement
                Text(entry.encouragement)
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "bibleplus://"))
    }

    // MARK: - Accessory Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Row 1: Time icon + greeting
            HStack(spacing: 4) {
                Image(systemName: entry.timeIcon)
                    .font(.system(size: 12, weight: .semibold))

                Text("\(entry.greeting), \(entry.firstName)")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }

            // Row 2: Encouragement
            Text(entry.encouragement)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .widgetURL(URL(string: "bibleplus://"))
    }
}
