import SwiftUI

struct QuickPromptsView: View {
    let prompts: [(icon: String, text: String)]
    let userName: String
    let categories: [PromptCategory]
    @Binding var selectedCategory: PromptCategory?
    var currentMode: ConversationMode? = nil
    let onTap: (String) -> Void
    var onSelectMode: ((ConversationMode) -> Void)? = nil
    var onSelectCharacter: ((BiblicalCharacter) -> Void)? = nil
    var onSelectEmotion: ((ChatEmotion) -> Void)? = nil
    var onGuidedPrayer: (() -> Void)? = nil

    @Environment(\.bpPalette) private var palette
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: max(geo.size.height * 0.15, 80))

                // Hero
                VStack(spacing: 10) {
                    Text("Hey \(userName)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)

                    Text("What\u{2019}s on\nyour heart?")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(BPAnimation.spring.delay(0.1), value: appeared)
                .padding(.bottom, 36)

                // Suggestions
                VStack(spacing: 10) {
                    suggestionRow(
                        icon: "wand.and.stars",
                        title: "Guided Prayer",
                        subtitle: "Build a personal prayer step by step"
                    ) {
                        onGuidedPrayer?()
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(BPAnimation.spring.delay(0.15), value: appeared)

                    ForEach(Array(prompts.prefix(4).enumerated()), id: \.element.text) { index, prompt in
                        suggestionRow(
                            icon: prompt.icon,
                            title: prompt.text
                        ) {
                            onTap(prompt.text)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(BPAnimation.spring.delay(0.18 + Double(index) * 0.04), value: appeared)
                    }
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Suggestion Row (unified card style)

    private func suggestionRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            HapticService.lightImpact()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: subtitle != nil ? 2 : 0) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.leading)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
}
