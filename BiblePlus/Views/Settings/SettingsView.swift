import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
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
        }
    }

}
