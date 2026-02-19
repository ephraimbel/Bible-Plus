import SwiftUI

struct QuickPromptsView: View {
    let prompts: [(icon: String, text: String)]
    let userName: String
    let categories: [PromptCategory]
    @Binding var selectedCategory: PromptCategory?
    let onTap: (String) -> Void

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
                .animation(BPAnimation.spring.delay(0.2), value: appeared)

                // Prompt cards
                VStack(spacing: 10) {
                    ForEach(Array(prompts.enumerated()), id: \.element.text) { index, prompt in
                        Button {
                            onTap(prompt.text)
                            HapticService.lightImpact()
                        } label: {
                            HStack(spacing: 14) {
                                // Icon circle
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
