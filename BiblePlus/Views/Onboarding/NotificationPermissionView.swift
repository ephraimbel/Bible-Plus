import SwiftUI

struct NotificationPermissionView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showContent = false

    private let benefits: [(icon: String, text: String)] = [
        ("sunrise", "Personalized prayers & verses at your chosen times"),
        ("flame", "Streak reminders to keep your momentum going"),
        ("book.pages", "Reading plan nudges so you never miss a day"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            // Bell icon with glow
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(palette.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.8)

            Spacer().frame(height: 28)

            // Heading
            Text("Stay Connected")
                .font(BPFont.onboardingHeading)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 10)

            // Subtitle
            Text("We'll send gentle reminders with personalized\nverses, streak encouragement, and\nreading plan nudges.")
                .font(BPFont.onboardingBody)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 28)

            // Benefit rows
            VStack(spacing: 16) {
                ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                    benefitRow(icon: benefit.icon, text: benefit.text)
                        .opacity(showContent ? 1 : 0)
                        .offset(x: showContent ? 0 : -20)
                        .animation(BPAnimation.staggered(index: index), value: showContent)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Actions
            VStack(spacing: 12) {
                GoldButton(
                    title: "Enable Notifications",
                    action: { viewModel.requestNotificationPermission() }
                )

                Button {
                    viewModel.goNext()
                } label: {
                    Text("Not now")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }
            }
            .padding(.horizontal, 32)

            Spacer().frame(height: 44)
        }
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(palette.accent.opacity(0.1))
                )

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}
