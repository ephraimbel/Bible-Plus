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
            Text(entry.displayText)
                .font(.custom("NewYork-Regular", size: 12, relativeTo: .caption))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let ref = entry.verseReference {
                Text(ref)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(deepLinkURL)
    }

    // MARK: - Deep Link

    private var deepLinkURL: URL? {
        guard let contentID = entry.contentID else { return nil }
        return URL(string: "bibleplus://content/\(contentID.uuidString)")
    }
}
