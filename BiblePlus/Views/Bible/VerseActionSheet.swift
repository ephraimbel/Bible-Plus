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
    let onMeditateInSanctuary: () -> Void
    let onShowPaywall: () -> Void
    let onDismiss: () -> Void
    @Environment(\.bpPalette) private var palette

    @State private var isEditingNote = false
    @State private var noteText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(palette.textMuted.opacity(0.25))
                .frame(width: 40, height: 4)
                .padding(.top, 10)

            // Verse preview
            VStack(spacing: 10) {
                Text(reference)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.accent)

                Text(verse.text)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .lineLimit(4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 16)

            // Highlight color dots
            highlightColorRow
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

            // Divider
            Rectangle()
                .fill(palette.border.opacity(0.2))
                .frame(height: 0.5)

            if isEditingNote {
                noteEditor
            } else {
                // Action buttons
                VStack(spacing: 2) {
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
                    actionRow(icon: "leaf.fill", title: "Meditate in Sanctuary", action: onMeditateInSanctuary)
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
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.bottom, 6)
        }
        .background(palette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 16, y: -4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Highlight Color Row (Pro-Gated)

    private var highlightColorRow: some View {
        HStack(spacing: 12) {
            ForEach(VerseHighlightColor.allCases) { color in
                let isLocked = color != .gold && !isPro
                let isActive = currentHighlight == color
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
                        // Outer ring for active
                        if isActive {
                            Circle()
                                .stroke(Color(hex: color.dotColor), lineWidth: 2)
                                .frame(width: 34, height: 34)
                        }

                        Circle()
                            .fill(Color(hex: color.dotColor))
                            .frame(width: 26, height: 26)
                            .opacity(isLocked ? 0.4 : 1)
                            .shadow(
                                color: isActive
                                    ? Color(hex: color.dotColor).opacity(0.4)
                                    : .clear,
                                radius: 4, y: 2
                            )

                        if isActive {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        } else if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(width: 36, height: 36)
                }
                .accessibilityLabel("\(color.displayName) highlight\(isLocked ? " (Pro)" : "")")
            }
        }
    }

    // MARK: - Note Editor

    private var noteEditor: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                Text("Personal Note")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Spacer()
            }

            TextEditor(text: $noteText)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(palette.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
                )

            HStack(spacing: 12) {
                if currentNote != nil && !currentNote!.isEmpty {
                    Button {
                        noteText = ""
                        onSaveNote("")
                        isEditingNote = false
                    } label: {
                        Text("Remove Note")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .stroke(.red.opacity(0.25), lineWidth: 1)
                            )
                    }
                }

                Spacer()

                Button {
                    onSaveNote(noteText.trimmingCharacters(in: .whitespacesAndNewlines))
                    isEditingNote = false
                } label: {
                    Text("Save Note")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [palette.accent, palette.accent.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: palette.accent.opacity(0.25), radius: 4, y: 2)
                        )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    // MARK: - Action Row

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.accent.opacity(0.08))
                    )

                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
        }
    }
}
