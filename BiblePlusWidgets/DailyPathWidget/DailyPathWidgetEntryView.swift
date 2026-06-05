import SwiftUI
import WidgetKit

struct DailyPathWidgetEntryView: View {
    let entry: DailyPathEntry
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
    //
    // The visual anchor is the day number, big and serif, on the gradient.
    // Underneath: path title (1-line) and a strip of progress dots so the
    // user can feel today's place in the larger arc at a glance.

    private var smallView: some View {
        ZStack {
            WidgetBackgroundView(gradientColors: entry.gradientColors)

            Group {
                if entry.isEmpty {
                    emptySmallView
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DAY")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)

                        Text("\(entry.currentDay)")
                            .font(.system(size: 44, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

                        Spacer(minLength: 0)

                        if let name = entry.pathName {
                            Text(name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                        }

                        progressDots
                            .padding(.top, 2)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(deepLinkURL)
    }

    private var emptySmallView: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 26))
                .foregroundStyle(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

            Text("Begin\nyour path")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)

            Spacer()
        }
        .padding(14)
    }

    // MARK: - System Medium
    //
    // Two-column layout: left = big day number + theme; right = path title,
    // "Day N of total", and the dots row. The day number stays the eye-magnet
    // (consistent with the small widget); the right column adds the context
    // a larger surface area can carry.

    private var mediumView: some View {
        ZStack {
            WidgetBackgroundView(gradientColors: entry.gradientColors)

            Group {
                if entry.isEmpty {
                    emptyMediumView
                } else {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DAY")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.7))
                                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)

                            Text("\(entry.currentDay)")
                                .font(.system(size: 56, weight: .semibold, design: .serif))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

                            if let theme = entry.themeLabel {
                                Text(theme)
                                    .font(.system(size: 11, weight: .medium))
                                    .italic()
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(2)
                                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                                    .padding(.top, 2)
                            }
                        }

                        Spacer(minLength: 4)

                        VStack(alignment: .leading, spacing: 8) {
                            if let name = entry.pathName {
                                Text(name)
                                    .font(.system(size: 15, weight: .semibold, design: .serif))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                            }

                            Text("\(entry.completedDays.count) of \(entry.totalDays) complete")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)

                            progressDots
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            Image(systemName: "leaf.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Begin Your Path")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 1, y: 1)

                Text("Fourteen days. Small steps. Real peace.")
                    .font(.system(size: 12))
                    .italic()
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    // MARK: - Accessory Rectangular (Lock Screen)

    private var rectangularView: some View {
        Group {
            if entry.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Begin Your Path")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Open Bible+ to start")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    if let name = entry.pathName {
                        Text("Day \(entry.currentDay) · \(name)")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    } else {
                        Text("Day \(entry.currentDay)")
                            .font(.system(size: 13, weight: .semibold))
                    }

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

                    Text("\(entry.completedDays.count)/\(entry.totalDays) complete")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
        .widgetURL(deepLinkURL)
    }

    // MARK: - Progress Strip
    //
    // For short paths (≤14 days) a row of dots reads instantly and shows the
    // user's exact place in the arc. For longer paths (21d, 30d) dots get
    // too cramped at the small-widget size; we fall back to a thin filled
    // capsule that still conveys progress + today marker without becoming
    // visual noise.

    @ViewBuilder
    private var progressDots: some View {
        if entry.totalDays > 14 {
            longPathProgressBar
        } else {
            shortPathDots
        }
    }

    private var shortPathDots: some View {
        let total = max(entry.totalDays, 1)
        let completed = Set(entry.completedDays)
        return HStack(spacing: 4) {
            ForEach(1...total, id: \.self) { day in
                let isDone = completed.contains(day)
                let isToday = day == entry.currentDay
                Circle()
                    .fill(
                        isDone
                            ? Color.white.opacity(0.95)
                            : (isToday ? Color.white.opacity(0.55) : Color.white.opacity(0.22))
                    )
                    .frame(width: isToday ? 6 : 4.5, height: isToday ? 6 : 4.5)
            }
        }
    }

    private var longPathProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(height: 4)
                Capsule()
                    .fill(.white.opacity(0.95))
                    .frame(width: geo.size.width * CGFloat(entry.completionFraction), height: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Deep Link

    private var deepLinkURL: URL? {
        if let pathID = entry.pathID {
            return URL(string: "bibleplus://path/\(pathID)")
        }
        return URL(string: "bibleplus://path")
    }
}
