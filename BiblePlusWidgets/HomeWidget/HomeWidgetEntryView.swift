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
            Spacer()

            Text(entry.displayText)
                .font(.custom("NewYork-Regular", size: 13, relativeTo: .body))
                .foregroundStyle(.white)
                .lineSpacing(2)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 0)

            if let ref = entry.verseReference {
                Text(ref)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
            }
        }
        .padding(12)
        .widgetURL(deepLinkURL)
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer()

            Text(entry.displayText)
                .font(.custom("NewYork-Regular", size: 15, relativeTo: .body))
                .foregroundStyle(.white)
                .lineSpacing(3)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 0)

            if let ref = entry.verseReference {
                Text(ref)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
            }
        }
        .padding(14)
        .widgetURL(deepLinkURL)
    }

    // MARK: - Large Widget

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()

            Text(entry.displayText)
                .font(.custom("NewYork-Regular", size: 18, relativeTo: .title3))
                .foregroundStyle(.white)
                .lineSpacing(4)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 0)

            if let ref = entry.verseReference {
                Text(ref)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                    .padding(.top, 2)
            }

            Spacer()

            HStack {
                Spacer()
                HStack(spacing: 5) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("Bible+")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.4))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
        }
        .padding(16)
        .widgetURL(deepLinkURL)
    }

    // MARK: - Helpers

    private var deepLinkURL: URL? {
        guard let contentID = entry.contentID else { return nil }
        return URL(string: "bibleplus://content/\(contentID.uuidString)")
    }
}
