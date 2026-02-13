import SwiftUI

struct AnswerNotesSheet: View {
    let entry: PrayerEntry
    @Bindable var viewModel: SavedViewModel
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("How did God answer this prayer?")
                    .font(BPFont.prayerSmall)
                    .foregroundStyle(palette.textPrimary)

                Text("Optional — you can leave this blank.")
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)

                TextEditor(text: $notes)
                    .font(BPFont.body)
                    .foregroundStyle(palette.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(palette.surface)
                    )

                Spacer()
            }
            .padding(20)
            .background(palette.background)
            .navigationTitle("Prayer Answered")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(palette.textMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.markPrayerAsAnswered(entry, notes: notes.trimmingCharacters(in: .whitespaces))
                        HapticService.success()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
