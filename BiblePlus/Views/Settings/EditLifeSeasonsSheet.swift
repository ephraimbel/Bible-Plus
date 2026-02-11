import SwiftUI

struct EditLifeSeasonsSheet: View {
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
                        Text("What season of life are you in?")
                            .font(BPFont.headingSmall)
                            .foregroundStyle(palette.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("Select up to 3")
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(LifeSeason.allCases) { season in
                            CompactSelectionCard(
                                title: season.displayName,
                                icon: season.icon,
                                isSelected: vm.editingLifeSeasons.contains(season),
                                action: { vm.toggleLifeSeason(season) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Life Seasons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        vm.saveLifeSeasons()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.accent)
                }
            }
        }
    }
}
