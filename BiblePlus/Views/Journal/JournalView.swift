import SwiftUI
import SwiftData

// MARK: - Journal (bottom-nav tab)
//
// A quiet, high-end journaling surface — a date-grouped list of entries with a
// distraction-free editor behind each. Warm Paper / Midnight, serif writing
// voice, smooth and responsive. Replaces the old Saved tab (Saved now lives in
// Profile).
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette

    @Query(sort: \JournalEntry.updatedAt, order: .reverse) private var entries: [JournalEntry]

    @State private var selectedEntry: JournalEntry?
    @State private var searchText = ""
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .background(palette.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Journal")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: newEntry) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(palette.accent)
                    }
                }
            }
            .navigationDestination(item: $selectedEntry) { entry in
                JournalEntryEditor(entry: entry)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(BPAnimation.spring) { appeared = true }
            }
        }
    }

    // MARK: List

    private var entryList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: BPSpacing.xl) {
                ForEach(Array(groupedEntries.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: BPSpacing.sm) {
                        Text(group.title.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.8)
                            .foregroundStyle(palette.textMuted)
                            .padding(.horizontal, 4)

                        VStack(spacing: BPSpacing.sm) {
                            ForEach(group.entries) { entry in
                                entryCard(entry)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, BPSpacing.lg)
            .padding(.top, BPSpacing.md)
            .padding(.bottom, 110)
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search entries")
        .opacity(appeared ? 1 : 0)
    }

    private func entryCard(_ entry: JournalEntry) -> some View {
        Button {
            HapticService.lightImpact()
            selectedEntry = entry
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.displayTitle)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let mood = entry.mood {
                        Image(systemName: mood.symbol)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(mood.tint)
                    }
                }

                if !entry.preview.isEmpty {
                    Text(entry.preview)
                        .font(.custom("Georgia", size: 14))
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Text(relativeDate(entry.updatedAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textMuted)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BPSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: BPRadius.md, style: .continuous)
                    .fill(palette.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: BPRadius.md, style: .continuous)
                            .strokeBorder(palette.border.opacity(0.5), lineWidth: 0.7)
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
        .contextMenu {
            Button(role: .destructive) { delete(entry) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: BPSpacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(palette.accent.opacity(0.10)).frame(width: 88, height: 88)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(palette.accent)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.85)

            VStack(spacing: BPSpacing.sm) {
                Text("Your journal")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                Text("A quiet place to reflect, pray, and remember\nwhat God is doing in your life.")
                    .font(.custom("Georgia", size: 15))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            GoldButton(title: "Write your first entry", showGlow: true) {
                newEntry()
            }
            .padding(.horizontal, 40)
            .padding(.top, BPSpacing.sm)
            .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BPSpacing.lg)
    }

    // MARK: Actions

    private func newEntry() {
        HapticService.lightImpact()
        let entry = JournalEntry()
        modelContext.insert(entry)
        selectedEntry = entry
    }

    private func delete(_ entry: JournalEntry) {
        HapticService.lightImpact()
        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    // MARK: Grouping

    private var filteredEntries: [JournalEntry] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter {
            $0.title.lowercased().contains(q) || $0.text.lowercased().contains(q)
        }
    }

    private var groupedEntries: [(title: String, entries: [JournalEntry])] {
        let calendar = Calendar.current
        var today: [JournalEntry] = []
        var yesterday: [JournalEntry] = []
        var week: [JournalEntry] = []
        var earlier: [JournalEntry] = []

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        for entry in filteredEntries {
            if calendar.isDateInToday(entry.updatedAt) { today.append(entry) }
            else if calendar.isDateInYesterday(entry.updatedAt) { yesterday.append(entry) }
            else if entry.updatedAt >= weekAgo { week.append(entry) }
            else { earlier.append(entry) }
        }

        var result: [(String, [JournalEntry])] = []
        if !today.isEmpty { result.append(("Today", today)) }
        if !yesterday.isEmpty { result.append(("Yesterday", yesterday)) }
        if !week.isEmpty { result.append(("This Week", week)) }
        if !earlier.isEmpty { result.append(("Earlier", earlier)) }
        return result
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today · \(formatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
