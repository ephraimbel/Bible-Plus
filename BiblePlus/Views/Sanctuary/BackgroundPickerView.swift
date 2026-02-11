import SwiftUI

struct BackgroundPickerView: View {
    @Bindable var vm: SanctuaryViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(BackgroundCollection.allCases) { collection in
                        Section {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(vm.backgroundsByCollection(collection)) { bg in
                                    backgroundCard(bg, locked: bg.isProOnly && !vm.profile.isPro)
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Text(collection.displayName)
                                    .font(BPFont.button)
                                    .foregroundStyle(.secondary)

                                if collection.isProOnly {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(hex: "C9A96E"))
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Backgrounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "C9A96E"))
                }
            }
        }
    }

    @ViewBuilder
    private func backgroundCard(_ bg: SanctuaryBackground, locked: Bool) -> some View {
        Button {
            if !locked {
                HapticService.selection()
                vm.selectBackground(bg)
            }
        } label: {
            ZStack {
                // Gradient preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: bg.gradientColors.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(1.2, contentMode: .fit)

                // Dark scrim for text
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.2))

                // Content overlay
                VStack(spacing: 4) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    } else if vm.selectedBackground.id == bg.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                    }

                    Text(bg.name)
                        .font(BPFont.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .opacity(locked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
