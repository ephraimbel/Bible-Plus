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
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 48)

                // Typography hero
                VStack(spacing: 14) {
                    Text("Hey \(userName)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)

                    Text("What\u{2019}s on\nyour heart?")
                        .font(.system(size: 32, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(BPAnimation.spring.delay(0.1), value: appeared)

                // Mode pills
                modePillsSection
                    .opacity(appeared ? 1 : 0)
                    .animation(BPAnimation.spring.delay(0.15), value: appeared)

                // "How are you feeling?"
                emotionSection
                    .opacity(appeared ? 1 : 0)
                    .animation(BPAnimation.spring.delay(0.18), value: appeared)

                // "Talk to..."
                characterSection
                    .opacity(appeared ? 1 : 0)
                    .animation(BPAnimation.spring.delay(0.2), value: appeared)

                // Category chip row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories) { category in
                            categoryChip(category)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .opacity(appeared ? 1 : 0)
                .animation(BPAnimation.spring.delay(0.22), value: appeared)

                // Prompt cards
                VStack(spacing: 10) {
                    // Guided Prayer card (special)
                    if selectedCategory == nil || selectedCategory == .prayer {
                        guidedPrayerCard
                    }

                    ForEach(Array(prompts.enumerated()), id: \.element.text) { index, prompt in
                        Button {
                            onTap(prompt.text)
                            HapticService.lightImpact()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(palette.accent.opacity(0.1))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: prompt.icon)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(palette.accent)
                                }

                                Text(prompt.text)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundStyle(palette.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(2)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(palette.textMuted)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(palette.surfaceElevated)
                                    .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
                            )
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(BPAnimation.spring.delay(0.25 + Double(index) * 0.04), value: appeared)
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Mode Pills

    private var modePillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ConversationMode.allCases) { mode in
                    let isSelected = currentMode == mode
                    Button {
                        onSelectMode?(mode)
                        HapticService.selection()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(mode.displayName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(isSelected ? .white : palette.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(isSelected ? palette.accent : palette.surfaceElevated)
                                .shadow(color: .black.opacity(isSelected ? 0 : 0.04), radius: 4, y: 2)
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : palette.border.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Emotion Section

    private var emotionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How are you feeling?")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 24)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                ForEach(ChatEmotion.allCases) { emotion in
                    Button {
                        onSelectEmotion?(emotion)
                        HapticService.lightImpact()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: emotion.icon)
                                .font(.system(size: 18, weight: .medium))
                            Text(emotion.displayName)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(palette.surfaceElevated)
                                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Character Section

    private var characterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Talk to...")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(BiblicalCharacter.allCases) { character in
                        Button {
                            onSelectCharacter?(character)
                            HapticService.lightImpact()
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [palette.accent.opacity(0.15), palette.accent.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 52, height: 52)

                                    Image(systemName: character.icon)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(palette.accent)
                                }

                                Text(character.displayName)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(palette.textPrimary)

                                Text(character.subtitle)
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                                    .foregroundStyle(palette.textMuted)
                                    .lineLimit(1)
                            }
                            .frame(width: 76)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Guided Prayer Card

    private var guidedPrayerCard: some View {
        Button {
            onGuidedPrayer?()
            HapticService.lightImpact()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent.opacity(0.2), palette.accent.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Guided Prayer")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                    Text("Build a personal prayer step by step")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.accent.opacity(0.2), lineWidth: 0.5)
            )
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
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? palette.accent : palette.surfaceElevated)
                    .shadow(color: .black.opacity(isSelected ? 0 : 0.04), radius: 4, y: 2)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : palette.border.opacity(0.2), lineWidth: 0.5)
            )
        }
    }
}
