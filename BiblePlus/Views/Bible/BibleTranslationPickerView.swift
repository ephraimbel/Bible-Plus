import SwiftUI

struct BibleTranslationPickerView: View {
    let currentTranslation: BibleTranslation
    let onSelect: (BibleTranslation) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

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
    }

    private func translationRow(_ translation: BibleTranslation) -> some View {
        let isSelected = translation == currentTranslation

        return Button {
            onSelect(translation)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(translation.displayName)
                        .font(BPFont.button)
                        .foregroundStyle(isSelected ? .white : palette.textPrimary)
                    Text(translation.subtitle)
                        .font(BPFont.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : palette.textMuted)
                }

                Spacer()

                if isSelected {
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
        }
        .buttonStyle(.plain)
    }
}
