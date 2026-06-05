import SwiftUI

// MARK: - Path Intro Overlay
//
// First-time entry into a path. Shown above PathDetailView the first time a
// user opens a specific path, before they've started day 1. The job is to
// present the path as a *journey* with shape — chapter arcs visible from
// the start — not just a list of 14 days to grind through.
//
// Dismissal options: "Begin Day 1" (primary CTA, fires onBegin) or the X
// close button (sets the seen-flag without starting). The seen-flag is keyed
// by pathID so each new path the user encounters gets its own intro moment.

struct PathIntroOverlay: View {
    let path: DailyPath
    let onBegin: () -> Void
    let onDismiss: () -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 24

    private var chapters: [PathChapter] { path.chapters }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        headerBlock
                            .padding(.top, 8)

                        if !chapters.isEmpty {
                            chapterTimeline
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                beginButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
            .opacity(contentOpacity)
            .offset(y: contentOffset)
        }
        .onAppear {
            guard !reduceMotion else {
                contentOpacity = 1; contentOffset = 0; return
            }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.85)) {
                contentOpacity = 1
                contentOffset = 0
            }
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(palette.surface)
                            .overlay(Circle().strokeBorder(palette.border, lineWidth: 0.8))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close intro")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DAILY PATH")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(palette.accent)

            Text(path.name)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .minimumScaleFactor(0.85)
                .lineLimit(2)

            Text(path.pathDescription)
                .font(.system(size: 16, design: .serif))
                .italic()
                .foregroundStyle(palette.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                Text("\(path.totalDays) days")
                Text("·")
                Text("about 5 minutes a day")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(palette.textMuted)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chapterTimeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YOUR JOURNEY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(palette.textMuted)

            // No connector line — evenly spaced numbered nodes, each vertically
            // centered against its title so 1·2·3·4 read as a clean column.
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    chapterRow(index: index, chapter: chapter)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chapterRow(index: Int, chapter: PathChapter) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(palette.accentSoft)
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)

                Text(chapter.dayRangeLabel)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(palette.textMuted)
            }

            Spacer(minLength: 0)
        }
    }

    private var beginButton: some View {
        Button {
            HapticService.lightImpact()
            onBegin()
        } label: {
            HStack(spacing: 8) {
                Text("Begin Day 1")
                    .font(.system(size: 17, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.accent)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Begin day one")
    }
}

// MARK: - Seen-flag persistence
//
// Keyed by path ID so each new path the user encounters gets its own intro
// moment. Stored as a simple UserDefaults Bool to avoid touching SwiftData
// for a piece of state that's purely about UI-onboarding.

enum PathIntroState {
    private static func key(pathID: String) -> String {
        "bibleplus.path.intro.shown.\(pathID)"
    }

    static func hasSeenIntro(for pathID: String) -> Bool {
        UserDefaults.standard.bool(forKey: key(pathID: pathID))
    }

    static func markIntroSeen(for pathID: String) {
        UserDefaults.standard.set(true, forKey: key(pathID: pathID))
    }
}
