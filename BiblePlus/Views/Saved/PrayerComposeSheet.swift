import SwiftUI

struct PrayerComposeSheet: View {
    @Bindable var viewModel: SavedViewModel
    let editingEntry: PrayerEntry?
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var category: PrayerCategory = .petition
    @State private var verseReference: String = ""

    private var isEditing: Bool { editingEntry != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title field
                    TextField("Prayer title...", text: $title)
                        .font(BPFont.prayerSmall)
                        .foregroundStyle(palette.textPrimary)

                    // Category picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textMuted)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(PrayerCategory.allCases) { cat in
                                    Button {
                                        category = cat
                                        HapticService.selection()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: cat.icon)
                                                .font(.system(size: 12))
                                            Text(cat.displayName)
                                                .font(BPFont.caption)
                                        }
                                        .foregroundStyle(category == cat ? .white : palette.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule().fill(category == cat ? palette.accent : palette.surface)
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Body text editor
                    TextEditor(text: $bodyText)
                        .font(BPFont.body)
                        .foregroundStyle(palette.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(palette.surface)
                        )

                    // Optional verse reference
                    TextField("Verse reference (optional)  e.g. Psalm 23:1", text: $verseReference)
                        .font(BPFont.body)
                        .foregroundStyle(palette.textSecondary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(palette.surface)
                        )
                }
                .padding(16)
            }
            .background(palette.background)
            .navigationTitle(isEditing ? "Edit Prayer" : "New Prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(palette.textMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        savePrayer()
                        HapticService.success()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let entry = editingEntry {
                    title = entry.title
                    bodyText = entry.body
                    category = entry.category
                    verseReference = entry.verseReference ?? ""
                }
            }
        }
    }

    private func savePrayer() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespaces)
        let ref = verseReference.trimmingCharacters(in: .whitespaces)

        if let entry = editingEntry {
            viewModel.updatePrayerEntry(
                entry,
                title: trimmedTitle,
                body: trimmedBody,
                category: category,
                verseReference: ref.isEmpty ? nil : ref
            )
        } else {
            viewModel.createPrayerEntry(
                title: trimmedTitle,
                body: trimmedBody,
                category: category,
                verseReference: ref.isEmpty ? nil : ref
            )
        }
    }
}
