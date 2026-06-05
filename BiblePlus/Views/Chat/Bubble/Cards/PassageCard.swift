import SwiftUI

// MARK: - Passage Reader Card
//
// An immersive "window into the Bible" embedded directly in the chat. Instead
// of a single quoted verse, the AI hands us a reference (book / chapter / range
// / focus) and this card loads the canonical text itself from BibleRepository
// and renders a SCROLLABLE reader the user can move through without leaving the
// conversation — the focus verse spotlit and auto-centred, the edges softly
// faded so it reads like a portal, a calm shimmer while it loads.
//
// Markup the model writes:
//   [PASSAGE book="John" chapter="3" range="1-21" focus="16"][/PASSAGE]
//
// Design notes (Warm Paper / Midnight, gold #C9A96E, serif scripture):
//  • Self-loading from references → never hallucinated, tiny payloads.
//  • Adaptive height: short passages shrink to fit; long ones cap and scroll.
//  • Edge fades + focus spotlight only appear once there's real content.
struct PassageCard: View {
    let book: String
    let chapter: Int
    let startVerse: Int?
    let endVerse: Int?
    let focusVerse: Int?
    let onScriptureTap: ((String, Int, Int) -> Void)?

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var verses: [(number: Int, text: String)] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var contentHeight: CGFloat = 0
    @State private var shimmer = false
    @State private var focusGlow = false

    private let maxWindowHeight: CGFloat = 320

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline
            window
            hairline
            footer
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.surfaceElevated))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        // A soft gold gradient blooming from behind the card — a warm, high-end
        // aura in place of a hard shadow or the old gold spine. Subtle: a touch
        // richer at the top, fading down, gently blurred so it reads as ambient
        // light rather than an outline.
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.34), palette.accent.opacity(0.12)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .blur(radius: 18)
                .offset(y: 7)
        )
        .padding(.vertical, 10)
        .task { await load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("PASSAGE")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(palette.accent.opacity(0.75))
                Text(referenceLabel)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
            }
            Spacer(minLength: 8)
            Text(translationAbbr)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(palette.accent.opacity(0.10)))
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 13)
    }

    // MARK: Scroll window

    @ViewBuilder
    private var window: some View {
        Group {
            if loadFailed {
                failedState
            } else if isLoading {
                loadingState
            } else {
                reader
            }
        }
        .frame(height: windowHeight)
        .animation(.easeInOut(duration: 0.3), value: contentHeight)
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }

    private var reader: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(verses, id: \.number) { verse in
                        verseRow(verse).id(verse.number)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: PassageHeightKey.self, value: geo.size.height)
                    }
                )
            }
            .onPreferenceChange(PassageHeightKey.self) { contentHeight = $0 }
            .mask(isScrollable ? AnyView(edgeFadeMask) : AnyView(Color.black))
            .onAppear { settleFocus(proxy: proxy) }
        }
    }

    private func verseRow(_ verse: (number: Int, text: String)) -> some View {
        let isFocus = focusVerse == verse.number
        return (
            Text("\(verse.number) ")
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundColor(palette.accent.opacity(isFocus ? 0.95 : 0.5))
                .baselineOffset(2)
            + Text(normalized(verse.text))
                .font(.custom("Georgia", size: 16))
                .foregroundColor(palette.textPrimary.opacity(isFocus ? 1.0 : 0.9))
        )
        .lineSpacing(7)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(palette.accent.opacity(isFocus && focusGlow ? 0.08 : 0))
        )
        .overlay(alignment: .leading) {
            if isFocus {
                RoundedRectangle(cornerRadius: 2)
                    .fill(palette.accent)
                    .frame(width: 2.5)
                    .padding(.vertical, 4)
                    .opacity(focusGlow ? 1 : 0)
            }
        }
    }

    private var edgeFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 20)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 20)
        }
    }

    // MARK: Loading / failed states

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(palette.textMuted.opacity(0.12))
                    .frame(height: 11)
                    .frame(maxWidth: i == 3 ? 160 : .infinity, alignment: .leading)
            }
        }
        .opacity(shimmer ? 0.45 : 1)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }

    private var failedState: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(palette.textMuted.opacity(0.6))
            Text("This passage isn't available offline.")
                .font(.system(size: 13))
                .foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: Footer

    private var footer: some View {
        Button {
            HapticService.lightImpact()
            onScriptureTap?(bookDisplayName, chapter, focusVerse ?? startVerse ?? 1)
        } label: {
            HStack(spacing: 5) {
                Spacer()
                Text("Open in Bible")
                    .font(.system(size: 12.5, weight: .semibold))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var hairline: some View {
        Rectangle()
            .fill(palette.border.opacity(0.14))
            .frame(height: 0.5)
    }

    // MARK: Derived values

    private var windowHeight: CGFloat {
        if isLoading || loadFailed { return 150 }
        if contentHeight <= 0 { return min(180, maxWindowHeight) }
        return min(contentHeight, maxWindowHeight)
    }

    private var isScrollable: Bool { contentHeight > maxWindowHeight + 1 }

    private var bookDisplayName: String { BibleData.resolveBook(book)?.name ?? book }

    private var translationAbbr: String { BibleRepository.shared.currentTranslation.abbreviation }

    private var referenceLabel: String {
        if let s = startVerse, let e = endVerse {
            return s == e ? "\(bookDisplayName) \(chapter):\(s)"
                          : "\(bookDisplayName) \(chapter):\(s)\u{2013}\(e)"
        }
        return "\(bookDisplayName) \(chapter)"
    }

    // MARK: Behavior

    private func settleFocus(proxy: ScrollViewProxy) {
        guard let focus = focusVerse, verses.contains(where: { $0.number == focus }) else {
            focusGlow = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) {
                proxy.scrollTo(focus, anchor: .center)
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.18)) {
                focusGlow = true
            }
        }
    }

    private func load() async {
        guard let resolved = BibleData.resolveBook(book) else {
            await MainActor.run { loadFailed = true; isLoading = false }
            return
        }
        do {
            let all = try await BibleRepository.shared.verses(book: resolved.id, chapter: chapter)
            let filtered: [(number: Int, text: String)]
            if let s = startVerse, let e = endVerse {
                let inRange = all.filter { $0.number >= s && $0.number <= e }
                filtered = inRange.isEmpty ? all : inRange
            } else {
                filtered = all
            }
            await MainActor.run {
                self.verses = filtered
                self.loadFailed = filtered.isEmpty
                self.isLoading = false
            }
        } catch {
            await MainActor.run { loadFailed = true; isLoading = false }
        }
    }

    /// Collapses stray newlines/tabs and repairs missing spaces after
    /// punctuation so the passage reads as clean flowing prose.
    private func normalized(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "[\\n\\r\\t]+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "([,.;:!?])([\\p{L}])", with: "$1 $2", options: .regularExpression)
        t = t.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PassageHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
