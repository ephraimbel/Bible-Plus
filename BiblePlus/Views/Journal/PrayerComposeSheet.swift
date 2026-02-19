import SwiftUI

struct PrayerComposeSheet: View {
    @Bindable var viewModel: JournalViewModel
    let editingEntry: PrayerEntry?
    var reflectionPrompt: String? = nil
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
                    // Reflection prompt banner
                    if let prompt = reflectionPrompt {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(palette.accent)
                                Text("Daily Reflection")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.textMuted)
                                    .textCase(.uppercase)
                                    .tracking(0.8)
                            }

                            Text(prompt)
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .foregroundStyle(palette.textPrimary)
                                .italic()
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(palette.accent.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(palette.accent.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }

                    // Title field
                    TextField("Prayer title...", text: $title)
                        .font(BPFont.prayerMedium)
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

                    // Inspirational text
                    Text("Pour out your heart to Him...")
                        .font(BPFont.body)
                        .foregroundStyle(palette.textMuted)
                        .italic()

                    // Body text editor
                    TextEditor(text: $bodyText)
                        .font(BPFont.body)
                        .foregroundStyle(palette.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 240)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(palette.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(palette.accent.opacity(0.08), lineWidth: 1)
                                )
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
                } else if reflectionPrompt != nil {
                    title = "Daily Reflection"
                    category = .gratitude
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
