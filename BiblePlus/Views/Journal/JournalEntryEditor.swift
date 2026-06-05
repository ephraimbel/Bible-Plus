import SwiftUI
import SwiftData

// MARK: - Journal Entry Editor
//
// A distraction-free writing surface — serif title + flowing body, an optional
// mood, and quiet autosave. Mirrors the calm of Notes / Day One: the page is
// the document, it grows as you write, and nothing competes with the words.
struct JournalEntryEditor: View {
    @Bindable var entry: JournalEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focus: Field?
    @State private var showMoodPicker = false
    @State private var didAppear = false

    private enum Field { case title, body }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: BPSpacing.md) {
                Text(dateLine)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(palette.textMuted)

                // Single-line (no `axis: .vertical`) so the field has a stable
                // intrinsic height — a multi-line title remeasures during the
                // navigation push and visibly jumps as the entry loads in.
                TextField("Title", text: $entry.title)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .focused($focus, equals: .title)
                    .submitLabel(.next)
                    .onChange(of: entry.title) { _, _ in touch() }
                    .onSubmit { focus = .body }

                if let mood = entry.mood {
                    moodPill(mood)
                }

                TextField("Write your heart…", text: $entry.text, axis: .vertical)
                    .font(.custom("Georgia", size: 17))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(7)
                    .focused($focus, equals: .body)
                    .onChange(of: entry.text) { _, _ in touch() }
                    .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)

                Spacer(minLength: 80)
            }
            .padding(.horizontal, BPSpacing.lg)
            .padding(.top, BPSpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(palette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    HapticService.lightImpact()
                    showMoodPicker = true
                } label: {
                    Image(systemName: entry.mood == nil ? "face.smiling" : "face.smiling.inverse")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(entry.mood?.tint ?? palette.accent)
                }

                Menu {
                    Button(role: .destructive) {
                        deleteAndDismiss()
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") { focus = nil }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .sheet(isPresented: $showMoodPicker) {
            moodPickerSheet
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            if entry.isBlank {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focus = .title }
            }
        }
        .onDisappear(perform: persist)
    }

    // MARK: Mood

    private func moodPill(_ mood: JournalMood) -> some View {
        Button {
            HapticService.lightImpact()
            showMoodPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mood.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(mood.label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(mood.tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(mood.tint.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    private var moodPickerSheet: some View {
        VStack(spacing: BPSpacing.lg) {
            Text("How are you feeling?")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .padding(.top, BPSpacing.lg)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BPSpacing.sm), count: 3), spacing: BPSpacing.sm) {
                ForEach(JournalMood.allCases) { mood in
                    let isSelected = entry.mood == mood
                    Button {
                        HapticService.lightImpact()
                        entry.mood = isSelected ? nil : mood
                        touch()
                        showMoodPicker = false
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mood.symbol)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(mood.tint)
                            Text(mood.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: BPRadius.sm, style: .continuous)
                                .fill(isSelected ? mood.tint.opacity(0.14) : palette.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: BPRadius.sm, style: .continuous)
                                        .strokeBorder(isSelected ? mood.tint.opacity(0.5) : .clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, BPSpacing.lg)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
    }

    // MARK: Persistence

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: entry.createdAt).uppercased()
    }

    private func touch() {
        entry.updatedAt = Date()
    }

    private func persist() {
        if entry.isBlank {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    private func deleteAndDismiss() {
        HapticService.lightImpact()
        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }
}
