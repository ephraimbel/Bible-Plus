import SwiftUI

// MARK: - Verse Toolbar Overlay

struct VerseToolbarOverlay: View {
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

    @State private var showHighlightStrip = false
    @State private var showNoteEditor = false
    @State private var showCopyConfirmation = false
    @State private var noteText = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrim
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Bottom stack: reference pill + highlight strip + toolbar
            VStack(spacing: 8) {
                // Reference pill
                Text(reference)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(palette.surfaceElevated)
                            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                    )
                    .overlay(
                        Capsule()
                            .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                    )

                // Highlight color strip (expandable)
                if showHighlightStrip {
                    HighlightColorStrip(
                        isPro: isPro,
                        currentHighlight: currentHighlight,
                        onHighlight: onHighlight,
                        onRemoveHighlight: onRemoveHighlight,
                        onShowPaywall: onShowPaywall
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Floating toolbar
                VerseFloatingToolbar(
                    isSaved: isSaved,
                    hasHighlight: currentHighlight != nil,
                    showingHighlightStrip: showHighlightStrip,
                    showCopyConfirmation: showCopyConfirmation,
                    onSave: {
                        if isSaved {
                            onUnsave()
                        } else {
                            onSave()
                        }
                    },
                    onExplain: onExplain,
                    onCopy: {
                        onCopy()
                        showCopyConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            showCopyConfirmation = false
                        }
                    },
                    onShare: onShare,
                    onHighlightToggle: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showHighlightStrip.toggle()
                        }
                    },
                    onPlayFromHere: onPlayFromHere,
                    onCreateVerseImage: onCreateVerseImage,
                    onMeditateInSanctuary: onMeditateInSanctuary,
                    onAddNote: {
                        noteText = currentNote ?? ""
                        showNoteEditor = true
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showHighlightStrip)
        .sheet(isPresented: $showNoteEditor) {
            VerseNoteEditorSheet(
                noteText: $noteText,
                hasExistingNote: currentNote != nil && !(currentNote?.isEmpty ?? true),
                onSave: { text in
                    onSaveNote(text)
                    showNoteEditor = false
                },
                onRemove: {
                    onSaveNote("")
                    showNoteEditor = false
                }
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Floating Toolbar

private struct VerseFloatingToolbar: View {
    let isSaved: Bool
    let hasHighlight: Bool
    let showingHighlightStrip: Bool
    let showCopyConfirmation: Bool
    let onSave: () -> Void
    let onExplain: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    let onHighlightToggle: () -> Void
    let onPlayFromHere: (() -> Void)?
    let onCreateVerseImage: () -> Void
    let onMeditateInSanctuary: () -> Void
    let onAddNote: () -> Void

    @Environment(\.bpPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            // Save
            toolbarButton(
                icon: isSaved ? "bookmark.fill" : "bookmark",
                isActive: isSaved,
                action: onSave
            )

            divider

            // Explain
            toolbarButton(
                icon: "bubble.left.and.bubble.right",
                action: onExplain
            )

            divider

            // Copy
            toolbarButton(
                icon: showCopyConfirmation ? "checkmark" : "doc.on.doc",
                isActive: showCopyConfirmation,
                action: onCopy
            )

            divider

            // Share
            toolbarButton(
                icon: "square.and.arrow.up",
                action: onShare
            )

            divider

            // Highlight
            toolbarButton(
                icon: "highlighter",
                isActive: showingHighlightStrip || hasHighlight,
                action: onHighlightToggle
            )

            divider

            // More (overflow menu)
            overflowMenu
        }
        .frame(height: 52)
        .background(
            Capsule()
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func toolbarButton(
        icon: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? palette.accent : palette.textSecondary)
                .frame(width: 44, height: 52)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(ToolbarButtonStyle())
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.border.opacity(0.15))
            .frame(width: 0.5, height: 24)
    }

    private var overflowMenu: some View {
        Menu {
            if let onPlayFromHere {
                Button {
                    onPlayFromHere()
                } label: {
                    Label("Play From Here", systemImage: "headphones")
                }
            }

            Button {
                onCreateVerseImage()
            } label: {
                Label("Create Verse Image", systemImage: "photo.artframe")
            }

            Button {
                onAddNote()
            } label: {
                Label("Add Note", systemImage: "note.text.badge.plus")
            }

            Button {
                onMeditateInSanctuary()
            } label: {
                Label("Meditate in Sanctuary", systemImage: "leaf.fill")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 44, height: 52)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Toolbar Button Style (press scale)

private struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Highlight Color Strip

private struct HighlightColorStrip: View {
    let isPro: Bool
    let currentHighlight: VerseHighlightColor?
    let onHighlight: (VerseHighlightColor) -> Void
    let onRemoveHighlight: () -> Void
    let onShowPaywall: () -> Void

    @Environment(\.bpPalette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            ForEach(VerseHighlightColor.allCases) { color in
                let isLocked = color != .gold && !isPro
                let isActive = currentHighlight == color

                Button {
                    if isLocked {
                        onShowPaywall()
                        return
                    }
                    HapticService.selection()
                    if currentHighlight == color {
                        onRemoveHighlight()
                    } else {
                        onHighlight(color)
                    }
                } label: {
                    ZStack {
                        if isActive {
                            Circle()
                                .stroke(Color(hex: color.dotColor), lineWidth: 2)
                                .frame(width: 30, height: 30)
                        }

                        Circle()
                            .fill(Color(hex: color.dotColor))
                            .frame(width: 22, height: 22)
                            .opacity(isLocked ? 0.4 : 1)
                            .shadow(
                                color: isActive
                                    ? Color(hex: color.dotColor).opacity(0.4)
                                    : .clear,
                                radius: 3, y: 1
                            )

                        if isActive {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        } else if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .accessibilityLabel("\(color.displayName) highlight\(isLocked ? " (Pro)" : "")")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
        .overlay(
            Capsule()
                .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
        )
    }
}

// MARK: - Note Editor Sheet

private struct VerseNoteEditorSheet: View {
    @Binding var noteText: String
    let hasExistingNote: Bool
    let onSave: (String) -> Void
    let onRemove: () -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $noteText)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(palette.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
                    )

                HStack(spacing: 12) {
                    if hasExistingNote {
                        Button {
                            onRemove()
                        } label: {
                            Text("Remove Note")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .stroke(.red.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }

                    Spacer()

                    Button {
                        onSave(noteText.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        Text("Save Note")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
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
            .padding(20)
            .background(palette.surfaceElevated)
            .navigationTitle("Personal Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
    }
}
