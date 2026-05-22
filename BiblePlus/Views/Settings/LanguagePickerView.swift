import SwiftUI

/// Full-screen sheet that lets the user pick the app's language. List is
/// searchable (native name, English name, or code all match) so a user who
/// only reads, say, Amharic can type "አማ" and find their entry instantly.
/// Selection is applied immediately — the picker dismisses and the rest of
/// the app re-renders in the new language via `LocalizationService`.
struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @Environment(LocalizationService.self) private var localization
    @State private var query: String = ""

    private var filtered: [SupportedLanguage] {
        SupportedLanguage.matches(query: query)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                palette.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    List {
                        // "System" row always visible, even during search — if
                        // the query doesn't match anything else the user can
                        // still tap it to reset.
                        if query.trimmingCharacters(in: .whitespaces).isEmpty ||
                           SupportedLanguage.system.englishName.localizedCaseInsensitiveContains(query) {
                            row(for: SupportedLanguage.system, isSystem: true)
                        }

                        if !filtered.isEmpty {
                            Section {
                                ForEach(filtered) { language in
                                    row(for: language, isSystem: false)
                                }
                            } header: {
                                Text("Languages")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(palette.textMuted)
                            }
                        } else {
                            Text("No languages match \"\(query)\"")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(palette.textMuted)
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Language")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textMuted)

            TextField("Search languages", text: $query)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func row(for language: SupportedLanguage, isSystem: Bool) -> some View {
        let isSelected: Bool = {
            if isSystem { return localization.currentCode == nil }
            return localization.currentCode == language.code
        }()

        Button {
            HapticService.selection()
            localization.setLanguage(isSystem ? nil : language)
            // Short beat so the user sees the checkmark land before dismissing.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                dismiss()
            }
        } label: {
            HStack(spacing: 14) {
                Text(language.flag)
                    .font(.system(size: 24))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.nativeName)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    if !isSystem && language.nativeName != language.englishName {
                        Text(language.englishName)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                    } else if isSystem {
                        Text("Follow device language")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }
}
