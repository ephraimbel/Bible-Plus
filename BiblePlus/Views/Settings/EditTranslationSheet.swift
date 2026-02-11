import SwiftUI

struct EditTranslationSheet: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Choose your Bible translation")
                        .font(BPFont.headingSmall)
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    ForEach(BibleTranslation.allCases) { translation in
                        SelectionCard(
                            title: translation.displayName,
                            subtitle: translation.subtitle,
                            icon: "book",
                            isSelected: vm.editingTranslation == translation,
                            action: { vm.editingTranslation = translation }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        vm.saveTranslation()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.accent)
                }
            }
            .background(palette.background)
            .toolbarBackground(palette.background, for: .navigationBar)
        }
        .presentationBackground(palette.background)
    }
}
