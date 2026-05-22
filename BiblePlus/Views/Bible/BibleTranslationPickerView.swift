import SwiftUI

/// Picker for the active Bible translation. Shows three bands:
///
/// 1. **Recommended** — the helloao default for the user's current app
///    language (e.g. Reina-Valera for Spanish). One tap puts the user on a
///    canonical translation for their language without scrolling.
/// 2. **English (bundled & online)** — the legacy `BibleTranslation` enum.
///    KJV and WEB are bundled and offline. NIV/ESV/NLT/etc. stream via the
///    legacy API and are Pro-gated.
/// 3. **All languages** — the full `TranslationCatalog` from bible.helloao.org,
///    searchable and grouped by language.
///
/// Two selection paths flow through two callbacks: `onSelectLegacy` persists
/// to `UserProfile.preferredTranslation`; `onSelectRef` persists to
/// `UserProfile.preferredTranslationRefID` via
/// `BibleReaderViewModel.changeTranslationRef(_:)`. The reader routes to the
/// right fetcher based on which of those is set.
struct BibleTranslationPickerView: View {
    let currentTranslation: BibleTranslation
    let currentRefID: String?
    let isPro: Bool
    let onSelectLegacy: (BibleTranslation) -> Void
    let onSelectRef: (TranslationRef) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @Environment(LocalizationService.self) private var localization
    @State private var catalog: TranslationCatalog = .shared
    @State private var query: String = ""
    @State private var showPaywall = false

    // MARK: - Derived state

    private var recommendedRef: TranslationRef? {
        let code = localization.current.code
        guard let refID = LanguageDefaultBible.defaultRefID(for: code),
              refID != LanguageDefaultBible.bundledEnglishID else {
            return nil
        }
        return catalog.translation(id: refID)
    }

    private var filteredLanguages: [(language: String, translations: [TranslationRef])] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return catalog.languages }
        let needle = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        var result: [(language: String, translations: [TranslationRef])] = []
        for group in catalog.languages {
            // Include whole group if language name matches.
            let groupMatches = group.language
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(needle)
            if groupMatches {
                result.append(group)
                continue
            }
            // Otherwise filter individual translations by name / short name.
            let hits = group.translations.filter { t in
                let haystacks = [t.englishName, t.nativeName, t.shortName]
                return haystacks.contains { h in
                    h.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle)
                }
            }
            if !hits.isEmpty {
                result.append((language: group.language, translations: hits))
            }
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    searchField
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if query.isEmpty {
                        recommendedSection
                        englishSection
                    }
                    allLanguagesSection
                }
                .padding(.bottom, 32)
            }
            .background(palette.background)
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(BPFont.button)
                        .foregroundStyle(palette.accent)
                }
            }
            .task {
                // Ensure the catalog is fresh when the picker opens. No-ops if
                // the manifest was recently refreshed (< 7d).
                catalog.refreshIfNeeded()
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallContainerView()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var recommendedSection: some View {
        if let ref = recommendedRef {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Recommended for \(localization.current.nativeName)")
                refRow(ref, highlight: true)
            }
            .padding(.horizontal, 16)
        }
    }

    private var englishSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("English")
            VStack(spacing: 8) {
                ForEach(BibleTranslation.allCases) { translation in
                    legacyRow(translation)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var allLanguagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(query.isEmpty ? "All Languages" : "Results")
            if catalog.translations.isEmpty && !catalog.isRefreshing {
                Text("No translations loaded yet. Pull to refresh from within the picker.")
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)
                    .padding(.horizontal, 16)
            } else if filteredLanguages.isEmpty {
                Text("No matches for \"\(query)\"")
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)
                    .padding(.horizontal, 16)
            } else {
                ForEach(filteredLanguages, id: \.language) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.language)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        ForEach(group.translations) { translation in
                            refRow(translation, highlight: false)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Rows

    private func legacyRow(_ translation: BibleTranslation) -> some View {
        let isSelected = currentRefID == nil && translation == currentTranslation
        let locked = translation.isProOnly && !isPro
        return Button {
            if locked {
                showPaywall = true
            } else {
                onSelectLegacy(translation)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(translation.abbreviation)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : palette.accent)
                            .frame(width: 44, alignment: .leading)
                        Text(translation.displayName)
                            .font(BPFont.button)
                            .foregroundStyle(isSelected ? .white : palette.textPrimary)
                    }
                    Text(translation.subtitle)
                        .font(BPFont.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : palette.textMuted)
                        .padding(.leading, 52)
                }
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.accent)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? palette.accent : palette.surface)
            )
            .opacity(locked ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func refRow(_ ref: TranslationRef, highlight: Bool) -> some View {
        let isSelected = currentRefID == ref.id
        return Button {
            onSelectRef(ref)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(ref.shortName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : palette.accent)
                            .frame(width: 52, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(ref.nativeName)
                            .font(BPFont.button)
                            .foregroundStyle(isSelected ? .white : palette.textPrimary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        Text(ref.coverage.label)
                            .font(BPFont.caption)
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : palette.textMuted)
                        if ref.englishName != ref.nativeName {
                            Text("·")
                                .foregroundStyle(isSelected ? .white.opacity(0.6) : palette.textMuted)
                            Text(ref.englishName)
                                .font(BPFont.caption)
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : palette.textMuted)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .padding(.leading, 60)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ? palette.accent
                        : highlight ? palette.surface.opacity(0.7)
                        : palette.surface
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(highlight ? palette.accent.opacity(0.4) : .clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textMuted)

            TextField("Search translations or languages", text: $query)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

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
                .fill(palette.surface)
        )
    }
}
