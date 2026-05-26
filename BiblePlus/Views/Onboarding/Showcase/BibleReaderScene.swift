import SwiftUI

// MARK: - Bible Reader Scene
//
// A live recreation of the Bible+ reader — faithful to ChapterReaderView: a
// serif chapter heading + ornamental divider on warm paper, flowing verses
// with superscript gold verse numbers. It animates the real interaction: the
// reader sits, a touch lands on John 3:16, the verse highlights (accentSoft),
// and the floating tools card pops up — exactly like VerseToolbarOverlay.
struct BibleReaderScene: View {
    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var versesIn = false
    @State private var selected = false        // verse 16 highlighted
    @State private var toolbarIn = false
    @State private var tapOpacity: Double = 0
    @State private var tapScale: CGFloat = 0.7
    @State private var rippleScale: CGFloat = 1
    @State private var rippleOpacity: Double = 0
    @State private var choreography: Task<Void, Never>? = nil

    private let verses: [(n: Int, t: String)] = [
        (14, "And as Moses lifted up the serpent in the wilderness, even so must the Son of man be lifted up:"),
        (15, "That whosoever believeth in him should not perish, but have eternal life."),
        (16, "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.")
    ]

    var body: some View {
        ZStack {
            palette.parchment

            VStack(spacing: 0) {
                navBar
                chapter
                Spacer(minLength: 0)
            }
            .padding(.top, 34)
        }
        .overlay {
            if toolbarIn {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.14)
                    toolbarCard
                        .padding(.horizontal, 12)
                        .padding(.bottom, 18)
                }
                .transition(.opacity)
            }
        }
        .onAppear { begin() }
        .onDisappear { choreography?.cancel(); choreography = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A preview of the Bible Plus reader: tapping John 3:16 opens the verse tools.")
    }

    // MARK: - Nav

    private var navBar: some View {
        HStack {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
            Spacer()
            Image(systemName: "textformat.size")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Chapter

    private var chapter: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("John 3")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, 8)

            OrnamentalDivider(color: palette.accent, opacity: 0.3)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)

            // Flowing verses (each its own row, like ChapterReaderView).
            VStack(alignment: .leading, spacing: 0) {
                ForEach(verses, id: \.n) { verse in
                    verseRow(verse.n, verse.t, isFocus: verse.n == 16)
                }
            }
        }
        .padding(.horizontal, 20)
        .opacity(versesIn ? 1 : 0)
    }

    private func verseRow(_ number: Int, _ text: String, isFocus: Bool) -> some View {
        let highlighted = isFocus && selected
        return (
            Text("\(number)")
                .font(.system(size: 10, weight: .semibold, design: .serif))
                .baselineOffset(5)
                .foregroundColor(palette.accent)
            + Text("\u{2009}")
                .font(.system(size: 15.5, design: .serif))
            + Text(text + " ")
                .font(.system(size: 15.5, weight: .regular, design: .serif))
                .foregroundColor(palette.textPrimary)
        )
        .lineSpacing(6)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(highlighted ? palette.accentSoft : .clear)
        )
        .overlay {
            if isFocus && tapOpacity > 0 { tapIndicator }
        }
    }

    // MARK: - Tap indicator (the "user clicking" touch)

    private var tapIndicator: some View {
        ZStack {
            Circle()
                .stroke(palette.accent.opacity(0.5), lineWidth: 2)
                .frame(width: 46, height: 46)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)

            Circle()
                .fill(palette.accent.opacity(0.22))
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(palette.accent.opacity(0.55), lineWidth: 1.5))
                .scaleEffect(tapScale)
        }
        .opacity(tapOpacity)
        .allowsHitTesting(false)
    }

    // MARK: - Tools card (mirrors VerseToolbarOverlay)

    private var toolbarCard: some View {
        VStack(spacing: 0) {
            Text("John 3:16")
                .font(.system(size: 12.5, weight: .semibold, design: .serif))
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.top, 11)
                .padding(.bottom, 8)

            Rectangle().fill(palette.border.opacity(0.15)).frame(height: 0.5)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    action("bookmark", "Save")
                    action("bubble.left.and.bubble.right", "Explain", emphasized: true)
                    action("doc.on.doc", "Copy")
                    action("square.and.arrow.up", "Share")
                    action("highlighter", "Highlight")
                }
                HStack(spacing: 0) {
                    action("headphones", "Play")
                    action("photo.artframe", "Image")
                    action("note.text.badge.plus", "Note")
                    Color.clear.frame(maxWidth: .infinity).frame(height: 50)
                    Color.clear.frame(maxWidth: .infinity).frame(height: 50)
                }
            }
            .padding(.vertical, 5)
        }
        .background(palette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.border.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 18, y: 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func action(_ icon: String, _ label: String, emphasized: Bool = false) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(emphasized ? palette.accent : palette.textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(emphasized ? palette.accent.opacity(0.12) : palette.accent.opacity(0.05)))
            Text(label)
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(emphasized ? palette.accent : palette.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
    }

    // MARK: - Choreography

    private func begin() {
        if reduceMotion {
            versesIn = true
            selected = true
            toolbarIn = true
            return
        }
        choreography = Task { @MainActor in await run() }
    }

    @MainActor
    private func run() async {
        withAnimation(.easeOut(duration: 0.5)) { versesIn = true }
        guard await pause(1.0) else { return }

        // Touch lands on verse 16.
        tapScale = 0.7
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            tapOpacity = 0.6
            tapScale = 1.0
        }
        guard await pause(0.55) else { return }

        // Press down.
        withAnimation(.easeIn(duration: 0.12)) { tapScale = 0.8 }
        guard await pause(0.14) else { return }

        // Release → verse selects, ripple expands.
        withAnimation(.easeOut(duration: 0.18)) { tapScale = 1.0 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selected = true }
        rippleScale = 1.0
        rippleOpacity = 0.6
        withAnimation(.easeOut(duration: 0.6)) {
            rippleScale = 2.0
            rippleOpacity = 0
        }
        guard await pause(0.18) else { return }

        // Tools card pops up; touch fades away.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { toolbarIn = true }
        withAnimation(.easeOut(duration: 0.3)) { tapOpacity = 0 }
    }

    @MainActor
    private func pause(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

#Preview("Bible Reader Scene") {
    ZStack {
        BPColorPalette.light.background.ignoresSafeArea()
        DeviceFrame(width: 270) {
            BibleReaderScene()
                .environment(\.bpPalette, .light)
        }
    }
}
