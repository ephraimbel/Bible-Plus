import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Environment(SoundscapeService.self) private var soundscapeService
    @State private var showSanctuary = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                // Profile section
                if let profile {
                    Section("Profile") {
                        LabeledContent("Name", value: profile.firstName)
                        LabeledContent("Faith Level", value: profile.faithLevel.displayName)
                        LabeledContent("Translation", value: profile.preferredTranslation.displayName)
                    }
                }

                // Sanctuary
                Section("Sanctuary") {
                    Button {
                        showSanctuary = true
                    } label: {
                        HStack {
                            Image(systemName: "moon.stars")
                                .foregroundStyle(Color(hex: "C9A96E"))
                            Text("Open Sanctuary")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Subscription
                Section("Subscription") {
                    if let profile {
                        LabeledContent("Status", value: profile.isPro ? "Pro" : "Free")
                    }
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $showSanctuary) {
                SanctuaryView(soundscapeService: soundscapeService)
            }
        }
    }
}
