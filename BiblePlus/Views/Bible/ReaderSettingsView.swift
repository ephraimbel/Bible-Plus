import SwiftUI

struct ReaderSettingsView: View {
    @Bindable var viewModel: BibleReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Live Preview
                    livePreviewSection

                    // Font Size
                    settingsSection(title: "Font Size") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Aa")
                                    .font(.system(size: 14, weight: .medium, design: currentDesign))
                                    .foregroundStyle(palette.textMuted)

                                Slider(
                                    value: $viewModel.readerFontSize,
                                    in: 14...30,
                                    step: 1
                                )
                                .tint(palette.accent)

                                Text("Aa")
                                    .font(.system(size: 24, weight: .medium, design: currentDesign))
                                    .foregroundStyle(palette.textMuted)
                            }

                            Text("\(Int(viewModel.readerFontSize))pt")
                                .font(BPFont.caption)
                                .foregroundStyle(palette.textMuted)
                        }
                    }

                    // Font Style
                    settingsSection(title: "Typeface") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(ReaderFontStyle.allCases) { style in
                                    fontStyleCard(style)
                                }
                            }
                        }
                    }

                    // Font Weight
                    settingsSection(title: "Font Weight") {
                        HStack(spacing: 10) {
                            ForEach(ReaderFontWeight.allCases) { weight in
                                fontWeightPill(weight)
                            }
                        }
                    }

                    // Line Spacing
                    settingsSection(title: "Line Spacing") {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 14))
                                    .foregroundStyle(palette.textMuted)

                                Slider(
                                    value: $viewModel.readerLineSpacing,
                                    in: 2...14,
                                    step: 1
                                )
                                .tint(palette.accent)

                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 18))
                                    .foregroundStyle(palette.textMuted)
                            }
                        }
                    }

                    // Text Alignment
                    settingsSection(title: "Text Alignment") {
                        HStack(spacing: 10) {
                            alignmentPill(label: "Left", icon: "text.alignleft", isJustified: false)
                            alignmentPill(label: "Justified", icon: "text.justify", isJustified: true)
                        }
                    }

                    // Verse Numbers
                    settingsSection(title: "Verse Numbers") {
                        Toggle(isOn: $viewModel.readerShowVerseNumbers) {
                            HStack(spacing: 10) {
                                Image(systemName: "number")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(palette.accent)
                                Text("Show verse numbers")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(palette.textPrimary)
                            }
                        }
                        .tint(palette.accent)
                    }

                    // Reset
                    Button {
                        viewModel.readerFontSize = 20
                        viewModel.readerFontStyle = .serif
                        viewModel.readerFontWeight = .regular
                        viewModel.readerLineSpacing = 6
                        viewModel.readerTextAlignmentJustified = false
                        viewModel.readerShowVerseNumbers = true
                        viewModel.persistReaderSettings()
                        HapticService.lightImpact()
                    } label: {
                        Text("Reset to Defaults")
                            .font(BPFont.button)
                            .foregroundStyle(palette.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(palette.surface)
                            )
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(palette.background)
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.persistReaderSettings()
                        dismiss()
                    }
                    .foregroundStyle(palette.accent)
                }
            }
            .onChange(of: viewModel.readerFontSize) { _, _ in viewModel.persistReaderSettings() }
            .onChange(of: viewModel.readerFontStyle) { _, _ in viewModel.persistReaderSettings() }
            .onChange(of: viewModel.readerFontWeight) { _, _ in viewModel.persistReaderSettings() }
            .onChange(of: viewModel.readerLineSpacing) { _, _ in viewModel.persistReaderSettings() }
            .onChange(of: viewModel.readerTextAlignmentJustified) { _, _ in viewModel.persistReaderSettings() }
            .onChange(of: viewModel.readerShowVerseNumbers) { _, _ in viewModel.persistReaderSettings() }
        }
    }

    // MARK: - Helpers

    private var currentDesign: Font.Design {
        viewModel.readerFontStyle.fontDesign
    }

    private var currentWeight: Font.Weight {
        viewModel.readerFontWeight.fontWeight
    }

    // MARK: - Live Preview

    private var livePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(BPFont.button)
                .foregroundStyle(palette.textPrimary)

            buildPreviewText()
                .lineSpacing(viewModel.readerLineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surface)
        )
    }

    private func buildPreviewText() -> Text {
        var result = Text("")

        // Verse 16
        if viewModel.readerShowVerseNumbers {
            let superSize = max(9, viewModel.readerFontSize * 0.55)
            result = result + Text("16")
                .font(.system(size: superSize, weight: .semibold, design: .serif))
                .foregroundColor(palette.accent)
                .baselineOffset(6)
            result = result + Text("\u{2009}")
                .font(.system(size: viewModel.readerFontSize, design: currentDesign))
        }
        result = result + Text("For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life. ")
            .font(.system(size: viewModel.readerFontSize, weight: currentWeight, design: currentDesign))
            .foregroundColor(palette.textPrimary)

        // Verse 17
        if viewModel.readerShowVerseNumbers {
            let superSize = max(9, viewModel.readerFontSize * 0.55)
            result = result + Text("17")
                .font(.system(size: superSize, weight: .semibold, design: .serif))
                .foregroundColor(palette.accent)
                .baselineOffset(6)
            result = result + Text("\u{2009}")
                .font(.system(size: viewModel.readerFontSize, design: currentDesign))
        }
        result = result + Text("For God sent not his Son into the world to condemn the world; but that the world through him might be saved.")
            .font(.system(size: viewModel.readerFontSize, weight: currentWeight, design: currentDesign))
            .foregroundColor(palette.textPrimary)

        return result
    }

    // MARK: - Font Style Card

    private func fontStyleCard(_ style: ReaderFontStyle) -> some View {
        let isSelected = viewModel.readerFontStyle == style

        return Button {
            viewModel.readerFontStyle = style
            HapticService.selection()
        } label: {
            VStack(spacing: 8) {
                Text(style.previewLetter)
                    .font(.system(size: 22, weight: .medium, design: style.fontDesign))
                    .foregroundStyle(isSelected ? .white : palette.textPrimary)

                Text(style.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : palette.textMuted)
            }
            .frame(width: 72, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? palette.accent : palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : palette.border.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Font Weight Pill

    private func fontWeightPill(_ weight: ReaderFontWeight) -> some View {
        let isSelected = viewModel.readerFontWeight == weight

        return Button {
            viewModel.readerFontWeight = weight
            HapticService.selection()
        } label: {
            Text(weight.displayName)
                .font(.system(size: 14, weight: weight.fontWeight))
                .foregroundStyle(isSelected ? .white : palette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? palette.accent : palette.surfaceElevated)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : palette.border.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Alignment Pill

    private func alignmentPill(label: String, icon: String, isJustified: Bool) -> some View {
        let isSelected = viewModel.readerTextAlignmentJustified == isJustified

        return Button {
            viewModel.readerTextAlignmentJustified = isJustified
            HapticService.selection()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : palette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? palette.accent : palette.surfaceElevated)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : palette.border.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings Section

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(BPFont.button)
                .foregroundStyle(palette.textPrimary)

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surface)
        )
    }
}
