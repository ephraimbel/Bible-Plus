import SwiftUI

struct SharePreviewSheet: View {
    let content: PrayerContent
    let displayText: String
    let theme: ThemeDefinition

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var selectedRatio: ShareAspectRatio = .story
    @State private var showActivitySheet = false
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Aspect ratio picker
                Picker("Format", selection: $selectedRatio) {
                    ForEach(ShareAspectRatio.allCases) { ratio in
                        Label(ratio.displayName, systemImage: ratio.icon)
                            .tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)

                // Live preview
                ShareCardView(
                    content: content,
                    displayText: displayText,
                    theme: theme,
                    aspectRatio: selectedRatio
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .padding(.horizontal, 24)

                Spacer()

                // Share button
                GoldButton(title: "Share") {
                    renderAndShare()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                if let image = renderedImage {
                    ActivityViewControllerRepresentable(activityItems: [image]) {
                        showActivitySheet = false
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }

    private func renderAndShare() {
        renderedImage = ShareService.renderShareImage(
            content: content,
            displayText: displayText,
            theme: theme,
            aspectRatio: selectedRatio
        )
        if renderedImage != nil {
            showActivitySheet = true
        }
    }
}
