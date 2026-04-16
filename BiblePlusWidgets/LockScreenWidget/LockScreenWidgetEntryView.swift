import SwiftUI
import WidgetKit

struct LockScreenWidgetEntryView: View {
    let entry: LockScreenWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    // MARK: - System Small

    private var smallView: some View {
        ZStack {
            WidgetBackgroundView(gradientColors: entry.backgroundGradient)

            VStack(alignment: .leading, spacing: 0) {
                // Reference as header
                if let ref = entry.verseReference {
                    Text(ref)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                }

                Spacer()

                Text(entry.displayText)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .lineSpacing(1.5)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 0)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(deepLinkURL)
    }

    // MARK: - Inline

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "book.closed.fill")
            Text(entry.shortText)
        }
        .widgetURL(deepLinkURL)
    }

    // MARK: - Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Reference as header
            if let ref = entry.verseReference {
                Text(ref)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(entry.displayText)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .lineSpacing(1)
                .minimumScaleFactor(0.6)
        }
        .widgetURL(deepLinkURL)
    }

    // MARK: - Deep Link

    private var deepLinkURL: URL? {
        guard let contentID = entry.contentID else { return nil }
        return URL(string: "bibleplus://content/\(contentID.uuidString)")
    }
}
