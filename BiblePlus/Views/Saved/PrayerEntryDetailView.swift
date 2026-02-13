import SwiftUI
import SwiftData

struct PrayerEntryDetailView: View {
    let entry: PrayerEntry
    @Bindable var viewModel: SavedViewModel
    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false
    @State private var showAnswerSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showAIChat = false
    @State private var aiConversationId: UUID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Category + Date header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: entry.category.icon)
                            .font(.system(size: 12))
                        Text(entry.category.displayName)
                            .font(BPFont.caption)
                    }
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(palette.accentSoft)
                    )

                    Spacer()

                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)
                }

                // Title
                Text(entry.title)
                    .font(BPFont.prayerMedium)
                    .foregroundStyle(palette.textPrimary)

                // Body
                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(BPFont.body)
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(6)
                }

                // Verse reference
                if let ref = entry.verseReference, !ref.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 12))
                        Text(ref)
                            .font(BPFont.reference)
                    }
                    .foregroundStyle(palette.accent)
                }

                Divider().foregroundStyle(palette.border)

                // Answered section
                if entry.isAnswered {
                    answeredSection
                } else {
                    markAnsweredButton
                }

                // "Pray With AI" button
                prayWithAIButton
            }
            .padding(20)
        }
        .background(palette.background)
        .navigationTitle("Prayer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditSheet = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            PrayerComposeSheet(viewModel: viewModel, editingEntry: entry)
        }
        .sheet(isPresented: $showAnswerSheet) {
            AnswerNotesSheet(entry: entry, viewModel: viewModel)
        }
        .sheet(isPresented: $showAIChat) {
            NavigationStack {
                ChatView(
                    conversationId: aiConversationId,
                    initialContext: buildAIContext()
                )
            }
        }
        .confirmationDialog("Delete Prayer?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deletePrayerEntry(entry)
                dismiss()
            }
        }
    }

    // MARK: - Answered Section

    private var answeredSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(palette.success)
                Text("Answered")
                    .font(BPFont.button)
                    .foregroundStyle(palette.success)

                if let date = entry.answeredAt {
                    Text("on \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)
                }
            }

            if !entry.answerNotes.isEmpty {
                Text(entry.answerNotes)
                    .font(BPFont.body)
                    .foregroundStyle(palette.textSecondary)
                    .italic()
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(palette.success.opacity(0.08))
                    )
            }

            Button {
                viewModel.unmarkPrayerAsAnswered(entry)
                HapticService.lightImpact()
            } label: {
                Text("Undo Answered")
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)
            }
        }
    }

    // MARK: - Mark Answered Button

    private var markAnsweredButton: some View {
        Button {
            showAnswerSheet = true
            HapticService.lightImpact()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                Text("Mark as Answered")
            }
            .font(BPFont.button)
            .foregroundStyle(palette.success)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.success.opacity(0.1))
            )
        }
    }

    // MARK: - Pray With AI Button

    private var prayWithAIButton: some View {
        Button {
            let conversation = Conversation(title: "Prayer: \(String(entry.title.prefix(30)))")
            modelContext.insert(conversation)
            try? modelContext.save()
            aiConversationId = conversation.id
            showAIChat = true
            HapticService.lightImpact()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("Pray With AI")
            }
            .font(BPFont.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.accent)
            )
        }
    }

    // MARK: - AI Context Builder

    private func buildAIContext() -> String {
        var prayerText = entry.title
        if !entry.body.isEmpty {
            prayerText += "\n\n\(entry.body)"
        }
        if let ref = entry.verseReference, !ref.isEmpty {
            prayerText += "\n\n(\(ref))"
        }
        return "I wrote this prayer in my journal and I'd like you to pray with me about it:\n\n\"\(prayerText)\""
    }
}
