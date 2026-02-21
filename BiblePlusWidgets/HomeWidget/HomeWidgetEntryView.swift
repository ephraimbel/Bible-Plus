import SwiftUI
import WidgetKit
import AppIntents

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
        ZStack {
            // Main content — tappable deep link
            Link(destination: deepLinkURL) {
                VStack(alignment: .leading, spacing: 0) {
                    contentTypeLabel(size: 9)

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

                    // Spacer for bottom navigation area
                    Spacer().frame(height: 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            // Navigation arrows at bottom
            VStack {
                Spacer()
                HStack {
                    navButton(intent: PreviousContentIntent(), icon: "chevron.left")
                    Spacer()
                    navButton(intent: NextContentIntent(), icon: "chevron.right")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        HStack(spacing: 0) {
            // Left chevron
            navButton(intent: PreviousContentIntent(), icon: "chevron.left")
                .padding(.leading, 4)

            // Main content
            Link(destination: deepLinkURL) {
                VStack(alignment: .leading, spacing: 0) {
                    contentTypeLabel(size: 9)

                    Spacer()

                    Text(entry.displayText)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                        .lineSpacing(3)
                        .lineLimit(5)
                        .minimumScaleFactor(0.75)
                        .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 0)

                    if let ref = entry.verseReference {
                        Text(ref)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.75))
                            .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                            .padding(.top, 5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            // Right chevron
            navButton(intent: NextContentIntent(), icon: "chevron.right")
                .padding(.trailing, 4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Large Widget

    private var largeView: some View {
        ZStack {
            // Main content — tappable deep link
            Link(destination: deepLinkURL) {
                VStack(alignment: .leading, spacing: 0) {
                    contentTypeLabel(size: 10)

                    Spacer()

                    Text(entry.displayText)
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                        .lineSpacing(4)
                        .minimumScaleFactor(0.75)
                        .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 0)

                    if let ref = entry.verseReference {
                        Text(ref)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.75))
                            .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                            .padding(.top, 6)
                    }

                    Spacer()

                    // Branding
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
                        Spacer()
                    }
                    // Space for bottom nav
                    Spacer().frame(height: 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            // Navigation arrows at bottom
            VStack {
                Spacer()
                HStack {
                    navButton(intent: PreviousContentIntent(), icon: "chevron.left")
                    Spacer()
                    navButton(intent: NextContentIntent(), icon: "chevron.right")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation Button

    private func navButton(intent: some AppIntent, icon: String) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(.white.opacity(0.1))
                )
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Type Label

    private func contentTypeLabel(size: CGFloat) -> some View {
        HStack(spacing: 4) {
            Image(systemName: contentTypeIcon)
                .font(.system(size: size, weight: .semibold))
            Text(contentTypeTitle)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(.white.opacity(0.6))
        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
    }

    private var contentTypeIcon: String {
        switch entry.contentType {
        case .verse: return "book.closed.fill"
        case .prayer: return "hands.sparkles.fill"
        case .devotional: return "text.book.closed.fill"
        case .quote: return "quote.opening"
        case .reflection: return "leaf.fill"
        }
    }

    private var contentTypeTitle: String {
        switch entry.contentType {
        case .verse: return "DAILY VERSE"
        case .prayer: return "DAILY PRAYER"
        case .devotional: return "DEVOTIONAL"
        case .quote: return "FAITH QUOTE"
        case .reflection: return "REFLECTION"
        }
    }

    // MARK: - Helpers

    private var deepLinkURL: URL {
        guard let contentID = entry.contentID else {
            return URL(string: "bibleplus://")!
        }
        return URL(string: "bibleplus://content/\(contentID.uuidString)")!
    }
}
