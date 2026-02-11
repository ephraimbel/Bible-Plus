import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @State private var apiKeyInput: String = AIService.apiKey
    @State private var showAPIKeySaved = false

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

                // AI Configuration
                Section {
                    SecureField("OpenAI API Key", text: $apiKeyInput)
                        .font(BPFont.body)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { saveAPIKey() }

                    Button("Save API Key") {
                        saveAPIKey()
                    }
                    .foregroundStyle(BPColorPalette.light.accent)

                    if showAPIKeySaved {
                        Text("API key saved successfully.")
                            .font(BPFont.caption)
                            .foregroundStyle(BPColorPalette.light.success)
                    }
                } header: {
                    Text("AI Companion")
                } footer: {
                    Text("Enter your OpenAI API key to enable the AI Bible companion. Your key is stored locally on this device.")
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

    private func saveAPIKey() {
        AIService.apiKey = apiKeyInput
        showAPIKeySaved = true
        HapticService.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showAPIKeySaved = false
        }
    }
}
