import SwiftUI
import WidgetKit

struct HomeWidgetEntryView: View {
    let entry: HomeWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            typeBadge

            Spacer()

            Text(entry.displayText)
                .font(.custom("NewYork-Regular", size: 14, relativeTo: .body))
                .foregroundStyle(.white)
                .lineLimit(4)
                .minimumScaleFactor(0.8)

            if let ref = entry.verseReference {
                Text(ref)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(12)
        .widgetURL(deepLinkURL)
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                typeBadge

                Spacer()

                Text(entry.displayText)
                    .font(.custom("NewYork-Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)

                if let ref = entry.verseReference {
                    Text(ref)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

            Image(systemName: "cross")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.trailing, 8)
        }
        .padding(14)
        .widgetURL(deepLinkURL)
    }

    // MARK: - Large Widget

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                typeBadge
                Spacer()
                Image(systemName: entry.window.icon)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Text(entry.displayText)
                .font(.custom("NewYork-Regular", size: 18, relativeTo: .title3))
                .foregroundStyle(.white)
                .lineLimit(8)
                .minimumScaleFactor(0.8)

            if let ref = entry.verseReference {
                Text(ref)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 2)
            }

            Spacer()

            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text("Bible+")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(16)
        .widgetURL(deepLinkURL)
    }

    // MARK: - Shared Components

    private var typeBadge: some View {
        Text(entry.contentType.displayName.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.15))
            .clipShape(Capsule())
    }

    private var deepLinkURL: URL? {
        guard let contentID = entry.contentID else { return nil }
        return URL(string: "bibleplus://content/\(contentID.uuidString)")
    }
}
