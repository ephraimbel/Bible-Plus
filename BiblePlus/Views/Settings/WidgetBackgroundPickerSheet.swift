import SwiftUI

struct WidgetBackgroundPickerSheet: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    @State private var selectedFilter: BackgroundFilter = .all
    @State private var showPaywall = false
    @Namespace private var chipAnimation

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    private var selectedWidgetBgID: String? {
        vm.profile.widgetSelectedBackgroundID
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // "Use App Background" option
                useAppBackgroundOption
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Divider
                Rectangle()
                    .fill(palette.border.opacity(0.15))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                // Filter chips
                filterChips

                // Background grid
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(filteredCollections()) { collection in
                            let backgrounds = filteredBackgrounds(in: SanctuaryBackground.backgrounds(in: collection))
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Text(collection.displayName.uppercased())
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .tracking(1.5)
                                        .foregroundStyle(palette.textMuted)

                                    if collection.isProOnly {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(palette.accent)
                                    }
                                }

                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(backgrounds) { bg in
                                        backgroundCard(bg, locked: bg.isProOnly && !vm.profile.isPro)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .animation(.easeInOut(duration: 0.25), value: selectedFilter)
                }
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Widget Background")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .presentationBackground(palette.background)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallContainerView()
        }
    }

    // MARK: - Use App Background Option

    private var useAppBackgroundOption: some View {
        let isActive = selectedWidgetBgID == nil
        let appBg = SanctuaryBackground.background(for: vm.profile.selectedBackgroundID)

        return Button {
            HapticService.selection()
            vm.updateWidgetBackground(nil)
        } label: {
            HStack(spacing: 14) {
                // Mini preview of app background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: (appBg?.gradientColors ?? ["#C9A96E", "#8B6914"]).map { Color(hex: $0) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "app.dashed")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Use App Background")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Text("Widget matches your app background")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isActive ? palette.accent.opacity(0.4) : palette.border.opacity(0.15),
                                lineWidth: isActive ? 1.5 : 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Chips

    @ViewBuilder
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BackgroundFilter.allCases) { filter in
                    filterChip(for: filter)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func filterChip(for filter: BackgroundFilter) -> some View {
        let isSelected = selectedFilter == filter

        Button {
            HapticService.selection()
            withAnimation(BPAnimation.selection) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .medium))

                Text(filter.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Text("\(backgroundCount(for: filter))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : palette.textMuted)
            }
            .foregroundStyle(isSelected ? .white : palette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: palette.accent.opacity(0.25), radius: 4, y: 2)
                        .matchedGeometryEffect(id: "activeWidgetChip", in: chipAnimation)
                } else {
                    Capsule()
                        .fill(palette.surfaceElevated)
                        .overlay(
                            Capsule()
                                .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filtering

    private func filteredCollections() -> [BackgroundCollection] {
        BackgroundCollection.allCases.filter { collection in
            let backgrounds = SanctuaryBackground.backgrounds(in: collection)
            return backgrounds.contains(where: { selectedFilter.matches($0) })
        }
    }

    private func filteredBackgrounds(in backgrounds: [SanctuaryBackground]) -> [SanctuaryBackground] {
        backgrounds.filter { selectedFilter.matches($0) }
    }

    private func backgroundCount(for filter: BackgroundFilter) -> Int {
        SanctuaryBackground.allBackgrounds.filter { filter.matches($0) }.count
    }

    // MARK: - Background Card

    @ViewBuilder
    private func backgroundCard(_ bg: SanctuaryBackground, locked: Bool) -> some View {
        let isActive = selectedWidgetBgID == bg.id

        Button {
            if locked {
                showPaywall = true
            } else {
                HapticService.selection()
                vm.updateWidgetBackground(bg.id)
            }
        } label: {
            ZStack {
                // Async thumbnail (gradient -> image/video thumbnail)
                AsyncThumbnailView(bg: bg)

                // Dark scrim for text
                Color.black.opacity(0.15)

                // Content overlay
                VStack(spacing: 6) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    } else if isActive {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.25))
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                    Text(bg.name)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Type badge for video/image backgrounds
                if bg.hasVideo || bg.hasImage {
                    VStack {
                        HStack {
                            Spacer()
                            Text(bg.hasVideo ? "ANIMATED" : "IMAGE")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "C9A96E").opacity(0.85))
                                )
                                .padding(5)
                        }
                        Spacer()
                    }
                }
            }
            .aspectRatio(3.0/4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isActive ? Color(hex: "C9A96E").opacity(0.6) : .white.opacity(0.1),
                        lineWidth: isActive ? 2 : 0.5
                    )
            )
            .shadow(
                color: isActive ? Color(hex: "C9A96E").opacity(0.2) : .clear,
                radius: 8, y: 4
            )
            .opacity(locked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
