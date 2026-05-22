import SwiftUI

/// Identifiable target for the inline scripture popover. Used by
/// `.sheet(item:)` so SwiftUI knows when to present a fresh sheet.
///
/// `verse` may be 0 when the user tapped a chapter-only reference like
/// "Psalm 23" — in that case the popover shows the chapter's opening verse.
struct ScriptureReferenceTarget: Identifiable {
    let id: String
    let bookName: String
    let chapter: Int
    let verse: Int

    init(bookName: String, chapter: Int, verse: Int) {
        self.bookName = bookName
        self.chapter = chapter
        self.verse = verse
        self.id = "\(bookName.lowercased())-\(chapter)-\(verse)"
    }

    var displayReference: String {
        if verse > 0 {
            return "\(bookName) \(chapter):\(verse)"
        }
        return "\(bookName) \(chapter)"
    }
}

/// In-conversation half-sheet that previews a verse without leaving the chat.
///
/// Replaces the prior "tap → navigate immediately to Bible reader" behavior.
/// On tap of any scripture reference (citation pill in body text, cross-ref
/// row, etc.) this sheet appears with the actual verse text fetched from
/// `BibleRepository`. The user can then explicitly choose to open the reader,
/// copy, share, or discuss the verse with the AI.
///
/// Premium principles enforced (consistent with rest of chat):
///   - Editorial typography (serif body, small-caps labels, hairlines)
///   - No icons in the body — only minimal SF Symbols on the action chips
///   - Translation indicator as small caps, no badge
///   - Loading state is a quiet typographic placeholder, not a spinner
struct ScripturePopoverSheet: View {
    let target: ScriptureReferenceTarget
    let onOpenInBible: () -> Void
    let onDiscuss: (String) -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var verseText: String? = nil
    @State private var actualVerseNumber: Int? = nil
    @State private var translationLabel: String = ""
    @State private var loadError: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            // Same warm-gradient background language as the conversation.
            backgroundGradient

            VStack(spacing: 0) {
                // Drag handle hint — minimal
                Capsule()
                    .fill(palette.border.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        verseBody
                        translationLine
                        actionRow
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(palette.background)
        .task {
            await loadVerse()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FROM SCRIPTURE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.7))

            Text(target.displayReference)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .animation(.easeOut(duration: 0.35).delay(0.05), value: appeared)
    }

    // MARK: - Verse Body

    @ViewBuilder
    private var verseBody: some View {
        if let text = verseText, !text.isEmpty {
            // The actual verse — italic serif, large, generous line height
            Text("\u{201C}\(text)\u{201D}")
                .font(.system(size: 19, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textPrimary.opacity(0.92))
                .lineSpacing(7)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
        } else if loadError {
            Text("This verse isn't available offline in your translation.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textMuted)
                .opacity(appeared ? 1 : 0)
        } else {
            // Quiet typographic loading state — no spinner.
            Text("…")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(palette.textMuted.opacity(0.5))
                .opacity(appeared ? 1 : 0)
        }
    }

    // MARK: - Translation Line

    @ViewBuilder
    private var translationLine: some View {
        if !translationLabel.isEmpty {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(palette.accent.opacity(0.4))
                    .frame(width: 18, height: 1)
                Text(translationLabel.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(palette.textMuted.opacity(0.6))
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.18), value: appeared)
        }
    }

    // MARK: - Action Row

    private var actionRow: some View {
        VStack(spacing: 10) {
            // Primary action — Open in Bible
            Button {
                HapticService.lightImpact()
                onOpenInBible()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text("Open in Bible")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: palette.accent.opacity(0.25), radius: 10, y: 5)
                )
            }
            .buttonStyle(.plain)

            // Secondary actions — Copy, Share, Discuss
            HStack(spacing: 10) {
                secondaryButton(label: "Copy", icon: "doc.on.doc") {
                    if let text = verseText {
                        UIPasteboard.general.string = "\"\(text)\" — \(target.displayReference)"
                        HapticService.success()
                    }
                }

                secondaryButton(label: "Share", icon: "square.and.arrow.up") {
                    shareVerse()
                }

                secondaryButton(label: "Discuss", icon: "sparkle") {
                    HapticService.lightImpact()
                    let prompt: String
                    if let text = verseText {
                        prompt = "Help me sit with this verse: \"\(text)\" — \(target.displayReference)"
                    } else {
                        prompt = "Help me understand \(target.displayReference)."
                    }
                    onDiscuss(prompt)
                    dismiss()
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(.easeOut(duration: 0.4).delay(0.22), value: appeared)
    }

    private func secondaryButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(palette.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.surfaceElevated.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let tint = palette.accent
        let strength: CGFloat = colorScheme == .dark ? 0.18 : 0.16
        let bg = palette.background

        return LinearGradient(
            stops: [
                .init(color: bg.blend(with: tint, amount: strength), location: 0.0),
                .init(color: bg.blend(with: tint, amount: strength * 0.6), location: 0.18),
                .init(color: bg, location: 0.45),
                .init(color: bg, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Verse Loading

    @MainActor
    private func loadVerse() async {
        let translation = BibleRepository.shared.currentTranslation
        translationLabel = translation.abbreviation

        do {
            let verses = try await BibleRepository.shared.verses(
                book: target.bookName,
                chapter: target.chapter,
                translation: translation
            )

            if target.verse > 0 {
                if let match = verses.first(where: { $0.number == target.verse }) {
                    verseText = match.text
                    actualVerseNumber = match.number
                    return
                }
                // Verse number requested but not found in this chapter — show
                // first verse with the chapter-only reference instead.
                if let first = verses.first {
                    verseText = first.text
                    actualVerseNumber = first.number
                    return
                }
            } else if let first = verses.first {
                verseText = first.text
                actualVerseNumber = first.number
                return
            }

            loadError = true
        } catch {
            loadError = true
        }
    }

    // MARK: - Share

    private func shareVerse() {
        guard let text = verseText else { return }
        let payload = "\"\(text)\" — \(target.displayReference)"
        let activity = UIActivityViewController(activityItems: [payload], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            // Present from the topmost view controller
            var presenter = root
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(activity, animated: true)
        }
    }
}
