import SwiftUI

struct ReaderSettingsView: View {
    @Bindable var viewModel: BibleReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                    settingsSection(title: "Font Style") {
                        VStack(spacing: 12) {
                            Picker("Font Style", selection: $viewModel.readerFontStyle) {
                                Text("Serif").tag(ReaderFontStyle.serif)
                                Text("Sans Serif").tag(ReaderFontStyle.sansSerif)
                            }
                            .pickerStyle(.segmented)

                            Text("For God so loved the world, that he gave his only begotten Son.")
                                .font(.system(
                                    size: viewModel.readerFontSize,
                                    weight: .regular,
                                    design: currentDesign
                                ))
                                .foregroundStyle(palette.textPrimary)
                                .lineSpacing(viewModel.readerLineSpacing)
                                .frame(maxWidth: .infinity, alignment: .leading)
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

                            // Preview
                            VStack(alignment: .leading, spacing: 0) {
                                sampleVerseLine(number: 1, text: "In the beginning God created the heaven and the earth.")
                                sampleVerseLine(number: 2, text: "And the earth was without form, and void.")
                            }
                        }
                    }

                    // Reset
                    Button {
                        viewModel.readerFontSize = 20
                        viewModel.readerFontStyle = .serif
                        viewModel.readerLineSpacing = 6
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
            .onChange(of: viewModel.readerLineSpacing) { _, _ in viewModel.persistReaderSettings() }
        }
    }

    private var currentDesign: Font.Design {
        viewModel.readerFontStyle == .serif ? .serif : .rounded
    }

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

    private func sampleVerseLine(number: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.system(
                    size: max(11, viewModel.readerFontSize * 0.65),
                    weight: .light,
                    design: .serif
                ))
                .foregroundStyle(palette.accent)
                .frame(width: 20, alignment: .trailing)

            Text(text)
                .font(.system(
                    size: viewModel.readerFontSize,
                    weight: .regular,
                    design: currentDesign
                ))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(viewModel.readerLineSpacing)
        }
        .padding(.vertical, 4)
    }
}
