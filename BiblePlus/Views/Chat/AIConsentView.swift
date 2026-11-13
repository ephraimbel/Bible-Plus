import SwiftUI

/// One-time disclosure + explicit permission screen shown before Bible+
/// sends anything to its third-party AI provider (App Store Guideline
/// 5.1.2(i)). Names the provider, lists exactly what is shared, and requires
/// an affirmative "Allow" tap. Declining leaves the rest of the app usable.
struct AIConsentView: View {
    let onAllow: () -> Void
    let onDecline: () -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Text("Before you chat")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity)

                Text("Bible+ answers your questions using an AI model provided by OpenAI, a third-party company. To personalize answers, we send the following to OpenAI through our secure server:")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textSecondary)

                VStack(alignment: .leading, spacing: 10) {
                    bullet("Your messages and voice transcripts in the chat")
                    bullet("Your first name")
                    bullet("Your onboarding answers: faith level, life season, and what you're carrying (for example grief or anxiety)")
                    bullet("Short memory notes Bible+ keeps about past conversations (you can clear these in Settings)")
                }

                Text("OpenAI processes this data to generate responses; under its API terms it is not used to train OpenAI's models. We never sell your data. Your journal is never sent.")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textSecondary)

                Text("By continuing, you confirm you are 18 or older, or that a parent or guardian has agreed to you using the AI companion.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textPrimary)

                Text("AI can make mistakes. It is not a pastor, counselor, or medical professional. If you are in crisis, call or text 988 (US) or your local emergency number.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textMuted)

                Button {
                    if let url = URL(string: "https://bibleplus.io/privacy") { openURL(url) }
                } label: {
                    Text("Read our Privacy Policy")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .underline()
                }

                VStack(spacing: 12) {
                    GoldButton(title: "Allow and Continue", action: onAllow)
                    Button(action: onDecline) {
                        Text("Not Now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 4)

                Text("You can withdraw permission anytime in Settings › AI & Privacy.")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .background(palette.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(palette.accent).frame(width: 5, height: 5).padding(.top, 7)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
