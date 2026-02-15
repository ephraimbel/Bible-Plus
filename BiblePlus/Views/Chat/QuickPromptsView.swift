import SwiftUI

struct QuickPromptsView: View {
    let prompts: [(icon: String, text: String)]
    let userName: String
    let categories: [PromptCategory]
    @Binding var selectedCategory: PromptCategory?
    let onTap: (String) -> Void

    @Environment(\.bpPalette) private var palette
    @State private var orbScale: CGFloat = 1.0
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                // Animated pulsing orb
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [palette.accent.opacity(0.3), palette.accent.opacity(0)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(orbScale)

                    // Inner gold circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: palette.accent.opacity(0.3), radius: 8, y: 4)

                    Image(systemName: "sparkle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(orbScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        orbScale = 1.15
                    }
                }

                // Welcome text
                VStack(spacing: 12) {
                    Text("Hey \(userName). I\u{2019}m here \u{2014} whether you\nneed to talk through a verse, sit with a\nhard question, or just need someone to\npray with you.")
                        .font(BPFont.body)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Text("What\u{2019}s on your heart?")
                        .font(BPFont.prayerSmall)
                        .foregroundStyle(palette.textPrimary)
                        .padding(.top, 4)
                }

                // Category chip row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories) { category in
                            categoryChip(category)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Prompt cards
                VStack(spacing: 10) {
                    ForEach(Array(prompts.enumerated()), id: \.element.text) { index, prompt in
                        Button {
                            onTap(prompt.text)
                            HapticService.lightImpact()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: prompt.icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(palette.accent)
                                    .frame(width: 20)

                                Text(prompt.text)
                                    .font(BPFont.body)
                                    .foregroundStyle(palette.textPrimary)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(palette.textMuted)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(palette.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(palette.border, lineWidth: 1)
                            )
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(BPAnimation.staggered(index: index), value: appeared)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            appeared = false
            withAnimation {
                appeared = true
            }
        }
    }

    // MARK: - Category Chip

    private func categoryChip(_ category: PromptCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(BPAnimation.selection) {
                if selectedCategory == category {
                    selectedCategory = nil
                } else {
                    selectedCategory = category
                }
            }
            HapticService.selection()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(category.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? .white : palette.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? palette.accent : palette.accent.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : palette.accent.opacity(0.25), lineWidth: 1)
            )
        }
    }
}
