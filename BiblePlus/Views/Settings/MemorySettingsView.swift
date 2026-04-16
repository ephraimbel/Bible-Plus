import SwiftUI
import SwiftData

// MARK: - Memory Settings
//
// User-facing view of "what Bible+ knows about you" — the trust layer for
// long-term AI memory. Shows three things:
//   1. Pinned facts — explicit, never-forget items the user (or the AI on
//      their behalf) has chosen to remember. Editable + deletable.
//   2. Rolling digest — the natural-language summary the AI maintains over
//      time. Editable so the user can correct anything wrong.
//   3. Danger zone — clear all memory in one tap (with confirmation).

struct MemorySettingsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette

    @State private var newFactText: String = ""
    @State private var editingDigest: Bool = false
    @State private var editedDigestText: String = ""
    @State private var showClearConfirm: Bool = false
    @FocusState private var newFactFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    pinnedFactsSection

                    digestSection

                    dangerZone

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("AI Memory")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent)
                }
            }
            .alert("Clear all AI memory?", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearAll()
                }
            } message: {
                Text("This deletes every pinned fact and the rolling digest. The AI will start fresh from your next message. This cannot be undone.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What Bible+ knows about you")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(palette.textPrimary)

            Text("Everything below is sent to the AI on every chat so it can remember you across conversations. You can edit, delete, or clear it any time.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Pinned Facts

    private var pinnedFactsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("PINNED FACTS", count: profile.aiPinnedFacts.count)

            sectionCard {
                if profile.aiPinnedFacts.isEmpty {
                    emptyFactsRow
                } else {
                    ForEach(Array(profile.aiPinnedFacts.enumerated()), id: \.element) { index, fact in
                        factRow(fact: fact, index: index)
                        if index < profile.aiPinnedFacts.count - 1 {
                            divider
                        }
                    }
                }

                divider

                addFactRow
            }

            Text("The AI pins facts here when you share something worth remembering forever (a name, a loss, an ongoing situation). You can also add facts yourself.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textMuted)
                .padding(.leading, 4)
                .padding(.top, 2)
        }
    }

    private var emptyFactsRow: some View {
        Text("No pinned facts yet. Tell the AI something like \u{201C}remember that I have a daughter named Sarah\u{201D} and it will appear here.")
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .italic()
            .foregroundStyle(palette.textMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func factRow(fact: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "pin.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 20, height: 20)
                .padding(.top, 1)

            Text(fact)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                HapticService.lightImpact()
                deleteFact(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var addFactRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.accent)

            TextField(
                "Add a fact",
                text: $newFactText,
                prompt: Text("Add a fact (e.g. \u{201C}Has a daughter named Sarah\u{201D})").foregroundColor(palette.textMuted.opacity(0.6))
            )
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundStyle(palette.textPrimary)
            .focused($newFactFocused)
            .submitLabel(.done)
            .onSubmit {
                addFact()
            }

            if !newFactText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    addFact()
                } label: {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Digest

    private var digestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("ROLLING DIGEST", count: nil)
                Spacer()
                if digestExists && !editingDigest {
                    Button {
                        editedDigestText = profile.aiMemoryDigest ?? ""
                        editingDigest = true
                    } label: {
                        Text("Edit")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            sectionCard {
                if editingDigest {
                    digestEditor
                } else if let digest = profile.aiMemoryDigest, !digest.isEmpty {
                    Text(digest)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(palette.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No digest yet. After a few conversations, Bible+ will start to build one.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundStyle(palette.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let updatedAt = profile.aiMemoryDigestUpdatedAt {
                Text("Last refreshed \(relativeDate(updatedAt))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textMuted.opacity(0.7))
                    .padding(.leading, 4)
            }
        }
    }

    private var digestEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $editedDigestText)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") {
                    editingDigest = false
                    editedDigestText = ""
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textMuted)

                Button("Save") {
                    saveDigestEdit()
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.accent)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DANGER ZONE", count: nil)

            Button {
                HapticService.lightImpact()
                showClearConfirm = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.error)
                        .frame(width: 24, height: 24)

                    Text("Clear All AI Memory")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.error)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.error.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(palette.error.opacity(0.18), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section Helpers

    private func sectionLabel(_ title: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(palette.textMuted)
            if let count {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.accent)
            }
        }
        .padding(.leading, 4)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.border.opacity(0.12))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    // MARK: - Actions

    private var digestExists: Bool {
        (profile.aiMemoryDigest?.isEmpty ?? true) == false
    }

    private func addFact() {
        let trimmed = newFactText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else { return }

        var current = profile.aiPinnedFacts
        // Case-insensitive dedupe.
        guard !current.contains(where: { $0.lowercased() == trimmed.lowercased() }) else {
            newFactText = ""
            return
        }
        current.append(trimmed)
        if current.count > 20 {
            current.removeFirst(current.count - 20)
        }
        profile.aiPinnedFacts = current
        try? modelContext.save()

        newFactText = ""
        newFactFocused = false
        HapticService.notification(.success)
    }

    private func deleteFact(at index: Int) {
        var current = profile.aiPinnedFacts
        guard index < current.count else { return }
        current.remove(at: index)
        profile.aiPinnedFacts = current
        try? modelContext.save()
    }

    private func saveDigestEdit() {
        let trimmed = editedDigestText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            profile.aiMemoryDigest = nil
        } else {
            profile.aiMemoryDigest = String(trimmed.prefix(800))
        }
        profile.aiMemoryDigestUpdatedAt = Date()
        try? modelContext.save()
        editingDigest = false
        editedDigestText = ""
        HapticService.notification(.success)
    }

    private func clearAll() {
        profile.aiPinnedFactsRaw = nil
        profile.aiMemoryDigest = nil
        profile.aiMemoryDigestUpdatedAt = nil
        profile.aiMessagesSinceDigestRefresh = 0
        try? modelContext.save()
        HapticService.notification(.warning)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
