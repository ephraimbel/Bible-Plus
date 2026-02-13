import SwiftUI

struct VerseActionSheet: View {
    let verse: VerseItem
    let reference: String
    let isSaved: Bool
    let isPro: Bool
    let currentHighlight: VerseHighlightColor?
    let currentNote: String?
    let onExplain: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onUnsave: () -> Void
    let onHighlight: (VerseHighlightColor) -> Void
    let onRemoveHighlight: () -> Void
    let onSaveNote: (String) -> Void
    let onPlayFromHere: (() -> Void)?
    let onCreateVerseImage: () -> Void
    let onShowPaywall: () -> Void
    let onDismiss: () -> Void
    @Environment(\.bpPalette) private var palette

    @State private var isEditingNote = false
    @State private var noteText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(palette.textMuted.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            // Verse preview
            VStack(spacing: 8) {
                Text(reference)
                    .font(BPFont.reference)
                    .foregroundStyle(palette.accent)

                Text(verse.text)
                    .font(BPFont.bibleMedium)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Highlight color dots
            highlightColorRow
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            Divider()
                .overlay(palette.border)

            if isEditingNote {
                noteEditor
            } else {
                // Action buttons
                VStack(spacing: 0) {
                    // Play from here
                    if let onPlayFromHere {
                        actionRow(icon: "headphones", title: "Play from Here", action: onPlayFromHere)
                    }

                    // Save / Unsave
                    if isSaved {
                        actionRow(icon: "bookmark.fill", title: "Unsave Verse", action: onUnsave)
                    } else {
                        actionRow(icon: "bookmark", title: "Save Verse", action: onSave)
                    }

                    // Add / Edit Note
                    let hasNote = currentNote != nil && !currentNote!.isEmpty
                    actionRow(
                        icon: hasNote ? "square.and.pencil" : "note.text.badge.plus",
                        title: hasNote ? "Edit Note" : "Add Note"
                    ) {
                        noteText = currentNote ?? ""
                        isEditingNote = true
                    }

                    actionRow(icon: "bubble.left.and.bubble.right", title: "Explain This Verse", action: onExplain)
                    actionRow(icon: "doc.on.doc", title: "Copy", action: onCopy)
                    actionRow(icon: "square.and.arrow.up", title: "Share", action: onShare)
                    actionRow(icon: "photo.artframe", title: "Create Verse Image", action: onCreateVerseImage)
                }
                .padding(.vertical, 8)
            }

            // Cancel
            Button {
                if isEditingNote {
                    isEditingNote = false
                } else {
                    onDismiss()
                }
            } label: {
                Text(isEditingNote ? "Back" : "Cancel")
                    .font(BPFont.button)
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.bottom, 8)
        }
        .background(palette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Highlight Color Row (Pro-Gated)

    private var highlightColorRow: some View {
        HStack(spacing: 10) {
            ForEach(VerseHighlightColor.allCases) { color in
                let isLocked = color != .gold && !isPro
                Button {
                    if isLocked {
                        onShowPaywall()
                        return
                    }
                    if currentHighlight == color {
                        onRemoveHighlight()
                    } else {
                        onHighlight(color)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: color.dotColor))
                            .frame(width: 28, height: 28)
                            .opacity(isLocked ? 0.4 : 1)

                        if currentHighlight == color {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .accessibilityLabel("\(color.displayName) highlight\(isLocked ? " (Pro)" : "")")
            }
        }
    }

    // MARK: - Note Editor

    private var noteEditor: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(palette.accent)
                Text("Personal Note")
                    .font(BPFont.button)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
            }

            TextEditor(text: $noteText)
                .font(BPFont.body)
                .foregroundStyle(palette.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(palette.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(palette.border, lineWidth: 1)
                )

            HStack(spacing: 12) {
                if currentNote != nil && !currentNote!.isEmpty {
                    Button {
                        noteText = ""
                        onSaveNote("")
                        isEditingNote = false
                    } label: {
                        Text("Remove Note")
                            .font(BPFont.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .stroke(.red.opacity(0.3), lineWidth: 1)
                            )
                    }
                }

                Spacer()

                Button {
                    onSaveNote(noteText.trimmingCharacters(in: .whitespacesAndNewlines))
                    isEditingNote = false
                } label: {
                    Text("Save Note")
                        .font(BPFont.button)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(palette.accent)
                        )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Action Row

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28)

                Text(title)
                    .font(BPFont.body)
                    .foregroundStyle(palette.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
}
