import SwiftUI

// MARK: - Memorize / Lock-In Card
//
// A focused, captivating way to commit a verse to heart, right inside the chat.
// The AI hands us a reference; the card loads the canonical verse and turns it
// into a progressive fill-in-the-blanks practice:
//
//   Practice  → ~⅓ of the words become gold blanks
//   Harder    → ~⅔ hidden
//   Harder    → every word hidden — recite it
//   Lock it in→ a quiet celebratory "Locked in", then an optional
//               spaced-repetition reminder ladder (next morning, +3d, +7d).
//
// Tap any blank to peek a single word. The whole thing is one verse only.
//
//   [MEMORIZE book="Philippians" chapter="4" verse="13"][/MEMORIZE]
struct MemorizeCard: View {
    let book: String
    let chapter: Int
    let verse: Int

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var verseText = ""
    @State private var isLoading = true
    @State private var loadFailed = false

    @State private var level = 0                 // 0 = full verse … 3 = all hidden
    @State private var revealed: Set<Int> = []   // words the user peeked this level
    @State private var peekAll = false
    @State private var lockedIn = false
    @State private var lockScale: CGFloat = 0.6
    @State private var reminderSet = false
    @State private var shimmer = false

    private let maxLevel = 3

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline
            content
            hairline
            footer
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

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MEMORIZE")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(palette.accent.opacity(0.75))
                Text(referenceLabel)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
            }
            Spacer(minLength: 8)
            progressRing
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 13)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(palette.accent.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(lockedIn ? maxLevel : level) / CGFloat(maxLevel))
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: lockedIn ? "checkmark" : "brain.head.profile")
                .font(.system(size: lockedIn ? 12 : 11, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
        .frame(width: 30, height: 30)
        .animation(.easeInOut(duration: 0.4), value: level)
        .animation(.easeInOut(duration: 0.4), value: lockedIn)
    }

    // MARK: Content states

    @ViewBuilder
    private var content: some View {
        Group {
            if loadFailed {
                failedState
            } else if isLoading {
                loadingState
            } else if lockedIn {
                lockedInState
            } else {
                practiceState
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }

    private var practiceState: some View {
        FlowLayout(spacing: 5, lineSpacing: 9) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                wordView(index: index, word: word)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.28), value: level)
        .animation(.easeInOut(duration: 0.2), value: peekAll)
    }

    @ViewBuilder
    private func wordView(index: Int, word: String) -> some View {
        if isHidden(index) {
            // A blank sized to the exact word footprint (clear text + gold
            // underline) so it sits perfectly inline. Tap to peek one word.
            Text(word)
                .font(.custom("Georgia", size: 18))
                .foregroundStyle(.clear)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(palette.accent.opacity(0.55))
                        .frame(height: 2)
                }
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(palette.accent.opacity(0.10))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticService.lightImpact()
                    withAnimation(.easeOut(duration: 0.2)) { _ = revealed.insert(index) }
                }
        } else {
            Text(word)
                .font(.custom("Georgia", size: 18))
                .foregroundStyle(revealed.contains(index) && !peekAll ? palette.accent : palette.textPrimary)
        }
    }

    private var lockedInState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(palette.accent.opacity(0.12)).frame(width: 58, height: 58)
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .scaleEffect(lockScale)

            Text("Locked in")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)

            Text(verseText)
                .font(.custom("Georgia", size: 15))
                .italic()
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6)) {
                lockScale = 1.0
            }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(palette.textMuted.opacity(0.12))
                    .frame(height: 12)
                    .frame(maxWidth: i == 2 ? 150 : .infinity, alignment: .leading)
            }
        }
        .opacity(shimmer ? 0.45 : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { shimmer = true }
        }
    }

    private var failedState: some View {
        Text("This verse isn't available offline.")
            .font(.system(size: 13))
            .foregroundStyle(palette.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if lockedIn {
            Button {
                guard !reminderSet else { return }
                HapticService.success()
                reminderSet = true
                Task {
                    await NotificationService.shared.scheduleMemoryReminders(
                        bookName: bookDisplayName, chapter: chapter,
                        verse: verse, reference: referenceLabel
                    )
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: reminderSet ? "checkmark" : "bell.badge")
                        .font(.system(size: 12, weight: .semibold))
                    Text(reminderSet ? "We'll remind you to review" : "Remind me to review")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(reminderSet ? palette.textMuted : palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .disabled(reminderSet)
        } else if !isLoading && !loadFailed {
            HStack(spacing: 10) {
                Button {
                    HapticService.lightImpact()
                    withAnimation(.easeInOut(duration: 0.2)) { peekAll.toggle() }
                } label: {
                    Text(peekAll ? "Hide" : "Show verse")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(palette.textMuted)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    advance()
                } label: {
                    HStack(spacing: 5) {
                        Text(primaryLabel)
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: level >= maxLevel ? "lock.fill" : "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(palette.accent))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    private var hairline: some View {
        Rectangle().fill(palette.border.opacity(0.14)).frame(height: 0.5)
    }

    // MARK: Logic

    private var words: [String] {
        verseText.split(separator: " ").map(String.init)
    }

    private func isHidden(_ index: Int) -> Bool {
        if peekAll || revealed.contains(index) { return false }
        switch level {
        case 0: return false
        case 1: return index % 3 == 2          // ~⅓
        case 2: return index % 3 != 0          // ~⅔
        default: return true                    // all
        }
    }

    private var primaryLabel: String {
        switch level {
        case 0: return "Practice"
        case maxLevel: return "Lock it in"
        default: return "Harder"
        }
    }

    private func advance() {
        if level >= maxLevel {
            HapticService.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { lockedIn = true }
            return
        }
        HapticService.lightImpact()
        withAnimation(.easeInOut(duration: 0.3)) {
            level += 1
            revealed.removeAll()
            peekAll = false
        }
    }

    private var bookDisplayName: String { BibleData.resolveBook(book)?.name ?? book }
    private var referenceLabel: String { "\(bookDisplayName) \(chapter):\(verse)" }

    private func load() async {
        guard let resolved = BibleData.resolveBook(book) else {
            await MainActor.run { loadFailed = true; isLoading = false }
            return
        }
        do {
            let all = try await BibleRepository.shared.verses(book: resolved.id, chapter: chapter)
            let text = all.first(where: { $0.number == verse })?.text
            await MainActor.run {
                if let text, !text.isEmpty {
                    self.verseText = normalized(text)
                } else {
                    self.loadFailed = true
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run { loadFailed = true; isLoading = false }
        }
    }

    private func normalized(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "[\\n\\r\\t]+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "([,.;:!?])([\\p{L}])", with: "$1 $2", options: .regularExpression)
        t = t.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Flow Layout
//
// A minimal wrapping layout so the verse's words + blanks reflow naturally
// across lines, like running text, while each remains an individually
// tappable view.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 9

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        let width = maxWidth == .infinity ? x : maxWidth
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
