import SwiftUI

struct WidgetBackgroundPickerSheet: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    @State private var showPaywall = false

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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // "Use App Background" option
                    useAppBackgroundOption

                    // Divider
                    Rectangle()
                        .fill(palette.border.opacity(0.15))
                        .frame(height: 0.5)
                        .padding(.horizontal, 4)

                    // Full background grid (same as BackgroundPickerView)
                    ForEach(BackgroundCollection.allCases) { collection in
                        let backgrounds = SanctuaryBackground.backgrounds(in: collection)
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
            SummaryPaywallView()
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
                // Gradient base
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: bg.gradientColors.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(0.75, contentMode: .fit)

                // Dark scrim for text
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.15))

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
            }
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
