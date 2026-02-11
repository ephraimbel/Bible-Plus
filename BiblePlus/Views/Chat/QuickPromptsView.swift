import SwiftUI

struct QuickPromptsView: View {
    let prompts: [String]
    let userName: String
    let onTap: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Welcome message
            VStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(BPColorPalette.light.accent)

                Text("\(userName), I'm here whenever you\nhave questions about Scripture\nor need a prayer.")
                    .font(BPFont.body)
                    .foregroundStyle(BPColorPalette.light.textSecondary)
                    .multilineTextAlignment(.center)

                Text("What's on your mind?")
                    .font(BPFont.prayerSmall)
                    .foregroundStyle(BPColorPalette.light.textPrimary)
                    .padding(.top, 4)
            }

            // Prompt chips
            VStack(spacing: 10) {
                ForEach(prompts, id: \.self) { prompt in
                    Button {
                        onTap(prompt)
                    } label: {
                        Text(prompt)
                            .font(BPFont.body)
                            .foregroundStyle(BPColorPalette.light.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(BPColorPalette.light.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(BPColorPalette.light.border, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}
