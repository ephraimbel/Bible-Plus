import SwiftUI

struct BibleTranslationPickerView: View {
    let currentTranslation: BibleTranslation
    let isPro: Bool
    let onSelect: (BibleTranslation) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(BibleTranslation.allCases) { translation in
                        translationRow(translation)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(palette.background)
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(BPFont.button)
                    .foregroundStyle(palette.accent)
                }
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallContainerView()
        }
    }

    private func translationRow(_ translation: BibleTranslation) -> some View {
        let isSelected = translation == currentTranslation
        let locked = translation.isProOnly && !isPro

        return Button {
            if locked {
                showPaywall = true
            } else {
                onSelect(translation)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(translation.abbreviation)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : palette.accent)
                            .frame(width: 40, alignment: .leading)
                        Text(translation.displayName)
                            .font(BPFont.button)
                            .foregroundStyle(isSelected ? .white : palette.textPrimary)
                    }
                    Text(translation.subtitle)
                        .font(BPFont.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : palette.textMuted)
                        .padding(.leading, 48)
                }

                Spacer()

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.accent)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? palette.accent : palette.surface)
            )
            .opacity(locked ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
