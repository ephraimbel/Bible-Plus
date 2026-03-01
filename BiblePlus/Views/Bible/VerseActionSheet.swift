import SwiftUI

// MARK: - Selected Verse Frame Preference Key

struct SelectedVerseFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

// MARK: - Verse Toolbar Overlay

struct VerseToolbarOverlay: View {
    let verse: VerseItem
    let reference: String
    let isSaved: Bool
    let isPro: Bool
    let currentHighlight: VerseHighlightColor?
    let currentNote: String?
    let verseFrame: CGRect
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
        GeometryReader { geo in
            let containerSize = geo.size
            let cardHeight: CGFloat = showHighlightStrip ? 230 : 165

            let showBelow = verseFrame != .zero
                && verseFrame.maxY + cardHeight + 16 < containerSize.height
            let showAbove = verseFrame != .zero
                && !showBelow
                && verseFrame.minY - cardHeight - 16 > 0

            let targetY: CGFloat = {
                if verseFrame == .zero {
                    return containerSize.height / 2
                } else if showBelow {
                    return verseFrame.maxY + 12 + cardHeight / 2
                } else if showAbove {
                    return verseFrame.minY - 12 - cardHeight / 2
                } else {
                    return containerSize.height / 2
                }
            }()

            ZStack {
                // Scrim
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                // Toolbar card
                toolbarCard
                    .frame(maxWidth: containerSize.width - 32)
                    .fixedSize(horizontal: false, vertical: true)
                    .position(x: containerSize.width / 2, y: targetY)
            }
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

    // MARK: - Toolbar Card

    private var toolbarCard: some View {
        VStack(spacing: 0) {
            // Reference header
            Text(reference)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Rectangle()
                .fill(palette.border.opacity(0.15))
                .frame(height: 0.5)

            // Action grid
            VStack(spacing: 0) {
                // Row 1: Save, Explain, Copy, Share, Highlight
                HStack(spacing: 0) {
                    actionItem(
                        icon: isSaved ? "bookmark.fill" : "bookmark",
                        label: isSaved ? "Unsave" : "Save",
                        isActive: isSaved
                    ) {
                        if isSaved { onUnsave() } else { onSave() }
                    }

                    actionItem(
                        icon: "bubble.left.and.bubble.right",
                        label: "Explain"
                    ) { onExplain() }

                    actionItem(
                        icon: showCopyConfirmation ? "checkmark" : "doc.on.doc",
                        label: "Copy",
                        isActive: showCopyConfirmation
                    ) {
                        onCopy()
                        showCopyConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            showCopyConfirmation = false
                        }
                    }

                    actionItem(
                        icon: "square.and.arrow.up",
                        label: "Share"
                    ) { onShare() }

                    actionItem(
                        icon: "highlighter",
                        label: "Highlight",
                        isActive: showHighlightStrip || currentHighlight != nil
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showHighlightStrip.toggle()
                        }
                    }
                }

                // Row 2: Play (optional), Image, Note, Meditate
                HStack(spacing: 0) {
                    if let playAction = onPlayFromHere {
                        actionItem(icon: "headphones", label: "Play") {
                            playAction()
                        }
                    }

                    actionItem(icon: "photo.artframe", label: "Image") {
                        onCreateVerseImage()
                    }

                    actionItem(icon: "note.text.badge.plus", label: "Note") {
                        noteText = currentNote ?? ""
                        showNoteEditor = true
                    }

                    actionItem(icon: "leaf.fill", label: "Meditate") {
                        onMeditateInSanctuary()
                    }
                }
            }
            .padding(.vertical, 6)

            // Expandable highlight color strip
            if showHighlightStrip {
                Rectangle()
                    .fill(palette.border.opacity(0.15))
                    .frame(height: 0.5)

                HighlightColorStrip(
                    isPro: isPro,
                    currentHighlight: currentHighlight,
                    onHighlight: onHighlight,
                    onRemoveHighlight: onRemoveHighlight,
                    onShowPaywall: onShowPaywall
                )
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .background(palette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Action Item

    private func actionItem(
        icon: String,
        label: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isActive ? palette.accent : palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isActive ? palette.accent.opacity(0.1) : palette.accent.opacity(0.04))
                    )
                    .contentTransition(.symbolEffect(.replace))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isActive ? palette.accent : palette.textMuted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarButtonStyle())
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
                        // Outer glow for active
                        if isActive {
                            Circle()
                                .fill(Color(hex: color.dotColor).opacity(0.12))
                                .frame(width: 36, height: 36)
                        }

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
                                radius: 4, y: 2
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
                    .frame(width: 36, height: 36)
                }
                .accessibilityLabel("\(color.displayName) highlight\(isLocked ? " (Pro)" : "")")
            }
        }
        .frame(maxWidth: .infinity)
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
                    .font(.system(size: 16, weight: .regular, design: .serif).italic())
                    .foregroundStyle(palette.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(palette.background)
                            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
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
