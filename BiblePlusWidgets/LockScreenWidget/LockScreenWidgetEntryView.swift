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
            WidgetBackgroundView(
                gradientColors: entry.backgroundGradient,
                imageData: entry.backgroundImageData
            )

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(entry.verseReference != nil ? "DAILY VERSE" : "DAILY INSPIRATION")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.5)
                }
                .foregroundStyle(.white.opacity(0.6))
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

                Spacer()

                Text(entry.displayText)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                    .lineLimit(5)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 0)

                if let ref = entry.verseReference {
                    Text(ref)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.75))
                        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                        .padding(.top, 4)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
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
        VStack(alignment: .leading, spacing: 3) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 8, weight: .semibold))
                Text(entry.verseReference != nil ? "DAILY VERSE" : "DAILY INSPIRATION")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.5)
            }
            .foregroundStyle(.secondary)

            Text(lockScreenText)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            if let ref = entry.verseReference {
                Text(ref)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(deepLinkURL)
    }

    /// Truncate long text to fit the lock screen rectangular widget comfortably
    private var lockScreenText: String {
        let text = entry.displayText
        let maxLength = 90
        guard text.count > maxLength else { return text }
        // Find a word boundary to truncate at
        let prefix = text.prefix(maxLength)
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[prefix.startIndex..<lastSpace]) + "\u{2026}"
        }
        return String(prefix) + "\u{2026}"
    }

    // MARK: - Deep Link

    private var deepLinkURL: URL? {
        guard let contentID = entry.contentID else { return nil }
        return URL(string: "bibleplus://content/\(contentID.uuidString)")
    }
}
