import SwiftUI

// MARK: - Typewriter Text
//
// Reveals a string character-by-character with natural pacing — short pause
// at commas, longer pause at sentence endings, very short pause between
// regular characters. The intent is to feel like a real friend typing,
// not a machine printing.
//
// Usage:
//
//     TypewriterText("Hey there. What should I call you?") {
//         // fired once when the reveal completes
//     }
//
// The whole text reveals on tap (skip-to-end). The reveal also auto-skips
// to the end if the same string is fed again with a different `id` —
// callers should put `.id(stepId)` on the parent to mount a fresh instance
// per step.

struct TypewriterText: View {
    let text: String
    var characterDelay: TimeInterval = 0.022
    var commaPause: TimeInterval = 0.10
    var sentencePause: TimeInterval = 0.22
    var lineBreakPause: TimeInterval = 0.30
    var font: Font = .system(size: 22, weight: .regular, design: .serif)
    var foreground: Color = .primary
    var lineSpacing: CGFloat = 6
    /// Optional character to render with a glowing gold treatment, matching
    /// the welcome screen's "Bible+" logo. The character keeps its original
    /// position in the text flow — we render an aligned overlay Text where
    /// every other glyph is clear, so only the highlight character casts
    /// shadow and the layout never reflows.
    var highlightCharacter: Character? = nil
    /// When set together with `highlightCharacter`, the character is replaced
    /// in the rendered text with this SF Symbol, drawn at the same font size
    /// so it inherits the line metrics. Use this to swap a "+" placeholder
    /// for an inline `sparkle` glyph that matches the brand logo.
    var highlightSymbol: String? = nil
    var highlightColor: Color = Color(red: 1.0, green: 0.84, blue: 0.3)
    var onComplete: (() -> Void)? = nil

    @State private var displayed: String = ""
    @State private var isComplete: Bool = false
    @State private var revealTask: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if let hc = highlightCharacter {
                ZStack(alignment: .topLeading) {
                    styledText(highlightChar: hc, mode: .base)
                    styledText(highlightChar: hc, mode: .overlay)
                        .shadow(color: highlightColor, radius: 4)
                        .shadow(color: highlightColor, radius: 10)
                        .shadow(color: highlightColor.opacity(0.7), radius: 20)
                        .shadow(color: highlightColor.opacity(0.4), radius: 40)
                }
            } else {
                styledText(highlightChar: nil, mode: .base)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap to reveal everything immediately. Useful for users
            // who already know what the prompt says or just want to skip.
            revealAll()
        }
        .onAppear {
            start()
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }

    private enum LayerMode {
        /// Base layer: highlight char is rendered as clear so the gold
        /// overlay shows through cleanly without doubled glyph weight.
        case base
        /// Overlay layer: every glyph is clear EXCEPT the highlight char,
        /// which is rendered in `highlightColor` and casts the glow shadow.
        case overlay
    }

    private func styledText(highlightChar hc: Character?, mode: LayerMode) -> some View {
        let baseColor: Color = (mode == .overlay) ? .clear : foreground
        let highlightFG: Color = (mode == .overlay) ? highlightColor : .clear

        // Walk the displayed string and assemble a Text via concatenation so
        // we can swap the highlight character for an SF Symbol image while
        // keeping everything else flowing as normal text. The two layers
        // (base + overlay) are constructed by the same builder with different
        // colors so their glyph metrics line up exactly.
        var result = Text("")
        var run = ""

        func flushRun() {
            if !run.isEmpty {
                result = result + Text(run).foregroundColor(baseColor)
                run = ""
            }
        }

        for ch in displayed {
            if let hc, ch == hc {
                flushRun()
                if let sym = highlightSymbol {
                    result = result + Text(Image(systemName: sym)).foregroundColor(highlightFG)
                } else {
                    result = result + Text(String(ch)).foregroundColor(highlightFG)
                }
            } else {
                run.append(ch)
            }
        }
        flushRun()

        return result
            .font(font)
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func start() {
        // Guard against double-starts on view re-render.
        guard displayed.isEmpty, !isComplete else { return }

        revealTask = Task { @MainActor in
            // Tiny initial pause so the message doesn't pop in the same
            // frame as the bubble appearing — gives the eye time to land.
            try? await Task.sleep(nanoseconds: 180_000_000)

            // Soft haptic when typing actually begins — signals to the user
            // "the AI is replying now" without being intrusive.
            HapticService.selection()

            for char in text {
                if Task.isCancelled { return }
                displayed.append(char)

                let delay = pauseAfter(char)
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
            // One last cancellation check before firing onComplete — guards
            // against the rare race where the parent view tears down the
            // bubble in the same instant the loop ends.
            if Task.isCancelled { return }

            isComplete = true
            onComplete?()
        }
    }

    private func revealAll() {
        revealTask?.cancel()
        revealTask = nil
        displayed = text
        if !isComplete {
            isComplete = true
            HapticService.selection()
            onComplete?()
        }
    }

    private func pauseAfter(_ char: Character) -> TimeInterval {
        switch char {
        case ".", "!", "?":
            return sentencePause
        case ",", ";", ":":
            return commaPause
        case "\n":
            return lineBreakPause
        default:
            return characterDelay
        }
    }
}
