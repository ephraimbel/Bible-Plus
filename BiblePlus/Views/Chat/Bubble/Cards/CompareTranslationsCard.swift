import SwiftUI

// MARK: - Compare Translations Card
//
// Shows ONE verse across 2–3 translations so the reader can see the nuance —
// where a literal rendering and a readable one diverge. The AI hands us a
// reference + a list of translation abbreviations; the card loads each verse
// itself from BibleRepository. Tap a row to focus it (the others recede) so a
// single reading can be isolated while comparing.
//
//   [COMPARE book="John" chapter="3" verse="16" translations="KJV,NIV,NLT"][/COMPARE]
struct CompareTranslationsCard: View {
    let book: String
    let chapter: Int
    let verse: Int
    let translations: [String]

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var loaded: [Row] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var focused: String?
    @State private var shimmer = false

    private struct Row: Identifiable {
        let id = UUID()
        let abbr: String
        let name: String
        let text: String
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline
            content
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.surfaceElevated))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [palette.accent.opacity(0.34), palette.accent.opacity(0.12)],
                                     startPoint: .top, endPoint: .bottom))
                .blur(radius: 18)
                .offset(y: 7)
        )
        .padding(.vertical, 10)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                Text("SIDE BY SIDE")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(2.2)
            }
            .foregroundStyle(palette.accent.opacity(0.78))
            Text(referenceLabel)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 13)
    }

    @ViewBuilder
    private var content: some View {
        if loadFailed {
            failedState
        } else if isLoading {
            loadingState
        } else {
            VStack(spacing: 0) {
                ForEach(Array(loaded.enumerated()), id: \.element.id) { index, row in
                    rowView(row)
                    if index < loaded.count - 1 { hairline }
                }
            }
        }
    }

    private func rowView(_ row: Row) -> some View {
        let isFocused = focused == row.abbr
        let dimOthers = focused != nil && !isFocused
        return Button {
            HapticService.lightImpact()
            withAnimation(.easeInOut(duration: 0.22)) {
                focused = isFocused ? nil : row.abbr
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(row.abbr)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(isFocused ? .white : palette.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(isFocused ? palette.accent : palette.accent.opacity(0.10)))
                    Text(row.name)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(row.text)
                    .font(.custom("Georgia", size: 16))
                    .italic()
                    .foregroundStyle(palette.textPrimary.opacity(dimOthers ? 0.4 : 0.95))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(isFocused ? palette.accent.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).fill(palette.accent.opacity(0.12)).frame(width: 44, height: 12)
                    RoundedRectangle(cornerRadius: 4).fill(palette.textMuted.opacity(0.12)).frame(height: 11)
                    RoundedRectangle(cornerRadius: 4).fill(palette.textMuted.opacity(0.12)).frame(maxWidth: 180).frame(height: 11)
                }
            }
        }
        .opacity(shimmer ? 0.45 : 1)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { shimmer = true }
        }
    }

    private var failedState: some View {
        Text("These translations aren't available offline right now.")
            .font(.system(size: 13))
            .foregroundStyle(palette.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 18)
    }

    private var hairline: some View {
        Rectangle().fill(palette.border.opacity(0.14)).frame(height: 0.5)
    }

    // MARK: Derived

    private var bookDisplayName: String { BibleData.resolveBook(book)?.name ?? book }
    private var referenceLabel: String { "\(bookDisplayName) \(chapter):\(verse)" }

    private func resolveTranslations() -> [BibleTranslation] {
        var chosen: [BibleTranslation] = translations.compactMap { abbr in
            BibleTranslation.allCases.first { $0.abbreviation.caseInsensitiveCompare(abbr) == .orderedSame }
        }
        if chosen.isEmpty {
            // A sensible default spread: the reader's current translation plus a
            // precise one and a readable one, so the range is visible.
            chosen = [BibleRepository.shared.currentTranslation, .esv, .nlt]
        }
        var seen = Set<BibleTranslation>()
        return Array(chosen.filter { seen.insert($0).inserted }.prefix(3))
    }

    // MARK: Load

    private func load() async {
        guard let resolved = BibleData.resolveBook(book) else {
            await MainActor.run { loadFailed = true; isLoading = false }
            return
        }
        var results: [Row] = []
        for translation in resolveTranslations() {
            if let verses = try? await BibleRepository.shared.verses(
                    book: resolved.id, chapter: chapter, translation: translation),
               let match = verses.first(where: { $0.number == verse }),
               !match.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                results.append(Row(abbr: translation.abbreviation,
                                   name: translation.displayName,
                                   text: normalized(match.text)))
            }
        }
        await MainActor.run {
            self.loaded = results
            self.loadFailed = results.count < 2   // a comparison needs at least two
            self.isLoading = false
        }
    }

    private func normalized(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "[\\n\\r\\t]+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "([,.;:!?])([\\p{L}])", with: "$1 $2", options: .regularExpression)
        t = t.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
