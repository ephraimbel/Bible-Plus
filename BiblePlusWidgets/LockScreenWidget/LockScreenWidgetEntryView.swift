import SwiftUI
import WidgetKit

struct LockScreenWidgetEntryView: View {
    let entry: LockScreenWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            inlineView
        }
    }

    // MARK: - Inline

    private var inlineView: some View {
        Text(entry.shortText)
            .widgetURL(deepLinkURL)
    }

    // MARK: - Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(lockScreenText)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .lineLimit(3)
                .minimumScaleFactor(0.9)

            if let ref = entry.verseReference {
                Text(ref)
                    .font(.system(size: 10, weight: .medium))
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
