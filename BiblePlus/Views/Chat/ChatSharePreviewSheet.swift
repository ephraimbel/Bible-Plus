import SwiftUI

struct ChatSharePreviewSheet: View {
    let messageContent: String
    let background: SanctuaryBackground

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var selectedRatio: ShareAspectRatio = .story
    @State private var showActivitySheet = false
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Format", selection: $selectedRatio) {
                    ForEach(ShareAspectRatio.allCases) { ratio in
                        Label(ratio.displayName, systemImage: ratio.icon)
                            .tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)

                GeometryReader { geo in
                    let cardWidth = selectedRatio.size.width / 3.0
                    let cardHeight = selectedRatio.size.height / 3.0
                    let scaleX = (geo.size.width - 48) / cardWidth
                    let scaleY = geo.size.height / cardHeight
                    let scale = min(scaleX, scaleY, 1.0)

                    ChatShareCardView(
                        messageContent: messageContent,
                        background: background,
                        aspectRatio: selectedRatio
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12 / scale))
                    .scaleEffect(scale)
                    .frame(width: cardWidth * scale, height: cardHeight * scale)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                GoldButton(title: "Share") {
                    renderAndShare()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Share as Card")
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
        renderedImage = ShareService.renderChatImage(
            messageContent: messageContent,
            background: background,
            aspectRatio: selectedRatio
        )
        if renderedImage != nil {
            showActivitySheet = true
        }
    }
}
