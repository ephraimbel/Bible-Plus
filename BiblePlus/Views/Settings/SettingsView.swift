import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                BPColorPalette.light.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "gearshape")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(BPColorPalette.light.accent)

                    Text("Settings")
                        .font(BPFont.headingMedium)
                        .foregroundStyle(BPColorPalette.light.textPrimary)

                    if let profile {
                        VStack(spacing: 8) {
                            Text("Welcome, \(profile.firstName)")
                                .font(BPFont.prayerSmall)
                                .foregroundStyle(BPColorPalette.light.accent)

                            Text("Translation: \(profile.preferredTranslation.displayName)")
                                .font(BPFont.body)
                                .foregroundStyle(BPColorPalette.light.textSecondary)

                            Text("Faith Level: \(profile.faithLevel.displayName)")
                                .font(BPFont.body)
                                .foregroundStyle(BPColorPalette.light.textSecondary)
                        }
                    }

                    Text("Full settings screen\ncoming soon.")
                        .font(BPFont.body)
                        .foregroundStyle(BPColorPalette.light.textMuted)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding(.horizontal, 32)
            }
        }
    }
}
