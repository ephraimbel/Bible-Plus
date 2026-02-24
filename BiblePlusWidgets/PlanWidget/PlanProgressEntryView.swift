import SwiftUI
import WidgetKit

struct PlanProgressEntryView: View {
    let entry: PlanProgressEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    // MARK: - System Small

    private var smallView: some View {
        ZStack {
            WidgetBackgroundView(gradientColors: entry.gradientColors)

            Group {
                if entry.isEmpty {
                    emptySmallView
                } else {
                    VStack(spacing: 8) {
                        Spacer()

                        // Circular progress ring
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 5)
                                .frame(width: 60, height: 60)

                            Circle()
                                .trim(from: 0, to: entry.completionFraction)
                                .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 0) {
                                Text("Day")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text("\(entry.currentDay)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                        if let name = entry.planName {
                            Text(name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                        }

                        Spacer()
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(deepLinkURL)
    }

    private var emptySmallView: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.6))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

            Text("Start a\nReading Plan")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)

            Spacer()
        }
        .padding(16)
    }

    // MARK: - System Medium

    private var mediumView: some View {
        ZStack {
            WidgetBackgroundView(gradientColors: entry.gradientColors)

            Group {
                if entry.isEmpty {
                    emptyMediumView
                } else {
                    HStack(spacing: 16) {
                        // Left: circular progress ring
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 6)
                                .frame(width: 70, height: 70)

                            Circle()
                                .trim(from: 0, to: entry.completionFraction)
                                .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .frame(width: 70, height: 70)
                                .rotationEffect(.degrees(-90))

                            Text("\(Int(entry.completionFraction * 100))%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                        // Right: plan details
                        VStack(alignment: .leading, spacing: 6) {
                            if let name = entry.planName {
                                Text(name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
                            }

                            Text("Day \(entry.currentDay) of \(entry.totalDays)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)

                            // Linear progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(.white.opacity(0.2))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(.white)
                                        .frame(width: geo.size.width * entry.completionFraction, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(deepLinkURL)
    }

    private var emptyMediumView: some View {
        HStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.6))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Start a Reading Plan")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 1, y: 1)

                Text("Grow your faith with guided daily readings.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    // MARK: - Accessory Rectangular

    private var rectangularView: some View {
        Group {
            if entry.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    Text("No Active Plan")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Open Bible+ to start one")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    if let name = entry.planName {
                        Text(name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.secondary.opacity(0.3))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(.primary)
                                .frame(width: geo.size.width * entry.completionFraction, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("Day \(entry.currentDay)/\(entry.totalDays)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
        .widgetURL(deepLinkURL)
    }

    // MARK: - Deep Link

    private var deepLinkURL: URL? {
        if let planID = entry.planID {
            return URL(string: "bibleplus://plans/\(planID)")
        }
        return URL(string: "bibleplus://plans")
    }
}
