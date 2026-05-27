import SwiftUI

/// Picker for the active Bible translation.
///
/// Shows the eight main English translations (`BibleTranslation.allCases`) as a
/// fixed, in-memory list so the sheet opens instantly with no lag — no catalog
/// build, no language grouping, and no network fetch on open. KJV and WEB are
/// bundled and offline; NIV/ESV/NLT/etc. stream and are Pro-gated.
///
/// Selection flows through `onSelectLegacy`, which persists to
/// `UserProfile.preferredTranslation` via `BibleReaderViewModel.changeTranslation(_:)`
/// and reloads the current chapter. `onSelectRef` / `currentRefID` are retained
/// in the signature for the caller but are not used by this fast 8-translation
/// picker.
struct BibleTranslationPickerView: View {
    let currentTranslation: BibleTranslation
    let currentRefID: String?
    let isPro: Bool
    let onSelectLegacy: (BibleTranslation) -> Void
    let onSelectRef: (TranslationRef) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var showPaywall = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("English")
                    VStack(spacing: 8) {
                        ForEach(BibleTranslation.allCases) { translation in
                            legacyRow(translation)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
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
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallContainerView()
        }
    }

    // MARK: - Rows

    private func legacyRow(_ translation: BibleTranslation) -> some View {
        // A legacy enum translation is the active one only when no helloao ref
        // override is set.
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

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
