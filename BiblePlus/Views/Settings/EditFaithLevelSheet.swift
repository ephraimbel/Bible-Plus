import SwiftUI

struct EditFaithLevelSheet: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Where are you on your faith journey?")
                    .font(BPFont.headingSmall)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                ForEach(FaithLevel.allCases) { level in
                    SelectionCard(
                        title: level.displayName,
                        subtitle: level.description,
                        icon: level.icon,
                        isSelected: vm.editingFaithLevel == level,
                        action: { vm.editingFaithLevel = level }
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Faith Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        vm.saveFaithLevel()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.accent)
                }
            }
        }
    }
}
