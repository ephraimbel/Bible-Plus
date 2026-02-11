import SwiftUI

struct EditBurdensSheet: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("What's weighing on your heart?")
                            .font(BPFont.headingSmall)
                            .foregroundStyle(palette.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("Select up to 3")
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Burden.allCases) { burden in
                            CompactSelectionCard(
                                title: burden.displayName,
                                icon: burden.icon,
                                isSelected: vm.editingBurdens.contains(burden),
                                action: { vm.toggleBurden(burden) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Heart Burdens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        vm.saveBurdens()
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
