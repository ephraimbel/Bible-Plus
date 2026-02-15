import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: JournalViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    JournalContentView(viewModel: vm)
                } else {
                    BPLoadingView().onAppear {
                        viewModel = JournalViewModel(modelContext: modelContext)
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Inner Content View

private struct JournalContentView: View {
    @Bindable var viewModel: JournalViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showComposeSheet = false
    @State private var appearAnimated = false

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            let items = viewModel.journalEntries

            if items.isEmpty {
                emptyJournal
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Warm gradient wash behind hero
                        Color.clear.frame(height: 0)
                            .background(
                                LinearGradient(
                                    colors: [palette.accent.opacity(0.04), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 280)
                                .offset(y: -40),
                                alignment: .top
                            )

                        // Hero: Daily Prompt + Stats
                        heroSection

                        // Filter Chips
                        filterChips

                        // Prayer List
                        LazyVStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                                NavigationLink {
                                    PrayerEntryDetailView(entry: entry, viewModel: viewModel)
                                } label: {
                                    JournalEntryCard(entry: entry, palette: palette)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                                .contextMenu {
                                    if !entry.isAnswered {
                                        Button {
                                            viewModel.markPrayerAsAnswered(entry, notes: "")
                                        } label: {
                                            Label("Mark Answered", systemImage: "checkmark.seal")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        viewModel.deletePrayerEntry(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)

                        // Bottom padding for FAB clearance
                        Spacer().frame(height: 80)
                    }
                }
                .scrollIndicators(.hidden)
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showComposeSheet = true
                        HapticService.impact(.medium)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
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
                            .shadow(color: palette.accent.opacity(0.35), radius: 12, y: 6)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .scaleEffect(appearAnimated ? 1 : 0.5)
                    .opacity(appearAnimated ? 1 : 0)
                }
            }

            // Answered Prayer Celebration Overlay
            if viewModel.showAnsweredCelebration {
                AnsweredCelebrationView(
                    prayerTitle: viewModel.celebrationPrayerTitle,
                    onDismiss: { viewModel.showAnsweredCelebration = false }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .sheet(isPresented: $showComposeSheet) {
            PrayerComposeSheet(viewModel: viewModel, editingEntry: nil)
        }
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.2)) {
                appearAnimated = true
            }
        }
    }

    // MARK: - Hero Section (Prompt + Stats)

    private var heroSection: some View {
        VStack(spacing: 0) {
            // Daily Prompt Card with decorative quote
            ZStack(alignment: .topLeading) {
                // Decorative curly quote
                Text("\u{201C}")
                    .font(.system(size: 80, weight: .bold, design: .serif))
                    .foregroundStyle(palette.accent.opacity(0.08))
                    .offset(x: 8, y: -12)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.accent)
                        Text("Daily Prompt")
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textMuted)
                            .textCase(.uppercase)
                            .tracking(0.8)
                    }

                    Text(viewModel.dailyPrompt)
                        .font(BPFont.prayerMedium)
                        .foregroundStyle(palette.textPrimary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        showComposeSheet = true
                        HapticService.lightImpact()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 13, weight: .medium))
                            Text("Write a Prayer")
                                .font(BPFont.button)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(palette.accent)
                        )
                    }
                    .padding(.top, 2)
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(palette.accent.opacity(0.25), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Stats Row
            statsRow
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 16) {
            let total = viewModel.totalPrayerCount
            let answered = viewModel.answeredPrayerCount

            HStack(spacing: 6) {
                Image(systemName: "book.pages")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.accent)
                Text("\(total) prayer\(total == 1 ? "" : "s")")
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            if answered > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.success)
                    Text("\(answered) answered")
                        .font(BPFont.caption)
                        .foregroundStyle(palette.success)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(JournalViewModel.JournalFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(BPAnimation.spring) {
                            viewModel.journalFilter = filter
                        }
                        HapticService.selection()
                    } label: {
                        Text(filter.displayName)
                            .font(BPFont.caption)
                            .foregroundStyle(
                                viewModel.journalFilter == filter
                                    ? .white
                                    : palette.textSecondary
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(
                                    viewModel.journalFilter == filter
                                        ? palette.accent
                                        : palette.surface
                                )
                            )
                    }
                }

                Divider().frame(height: 20)

                ForEach(PrayerCategory.allCases) { category in
                    Button {
                        withAnimation(BPAnimation.spring) {
                            viewModel.journalCategoryFilter =
                                viewModel.journalCategoryFilter == category ? nil : category
                        }
                        HapticService.selection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.system(size: 10))
                            Text(category.displayName)
                                .font(BPFont.caption)
                        }
                        .foregroundStyle(
                            viewModel.journalCategoryFilter == category
                                ? .white
                                : palette.textSecondary
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(
                                viewModel.journalCategoryFilter == category
                                    ? palette.accent
                                    : palette.surface
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Empty State

    private var emptyJournal: some View {
        VStack(spacing: 24) {
            Spacer()

            // Pulsing glowing icon
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.08))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(palette.accent.opacity(0.05))
                    .frame(width: 88, height: 88)

                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(palette.accent)
            }

            VStack(spacing: 10) {
                Text("Your Prayer Journal")
                    .font(BPFont.headingSmall)
                    .foregroundStyle(palette.textPrimary)

                Text("This is your sacred space to pour out\nyour heart, lift up your prayers, and\ncelebrate when God answers.")
                    .font(BPFont.body)
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                HapticService.impact(.medium)
                showComposeSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 14, weight: .medium))
                    Text("Write Your First Prayer")
                        .font(BPFont.button)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(palette.accent)
                )
                .shadow(color: palette.accent.opacity(0.25), radius: 8, y: 4)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Journal Entry Card

private struct JournalEntryCard: View {
    let entry: PrayerEntry
    let palette: BPColorPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: category + date + answered badge
            HStack(spacing: 8) {
                Image(systemName: entry.category.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.accent)

                Text(entry.category.displayName)
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)

                Spacer()

                if entry.isAnswered {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                        Text("Answered")
                            .font(BPFont.caption)
                    }
                    .foregroundStyle(palette.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(palette.success.opacity(0.12))
                    )
                }

                Text(entry.createdAt.formatted(.relative(presentation: .named)))
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)
            }

            // Title
            Text(entry.title)
                .font(BPFont.prayerSmall)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)

            // Body preview
            if !entry.body.isEmpty {
                Text(entry.body)
                    .font(BPFont.body)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .lineSpacing(2)
            }

            // Verse reference
            if let ref = entry.verseReference, !ref.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 10))
                    Text(ref)
                        .font(BPFont.reference)
                }
                .foregroundStyle(palette.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            entry.isAnswered
                                ? palette.success.opacity(0.2)
                                : palette.border.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        // Left accent line
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(entry.isAnswered ? palette.success.opacity(0.5) : palette.accent.opacity(0.4))
            .frame(width: 3)
        }
    }
}

// MARK: - Prayer Entry Row (kept for backward compat)

struct PrayerEntryRow: View {
    let entry: PrayerEntry
    let palette: BPColorPalette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.category.icon)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(palette.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.title)
                        .font(BPFont.button)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if entry.isAnswered {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.success)
                    }
                }

                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(BPFont.body)
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(entry.category.displayName)
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)

                    Text("\u{00B7}")
                        .foregroundStyle(palette.textMuted)

                    Text(entry.createdAt.formatted(.relative(presentation: .named)))
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)

                    if let ref = entry.verseReference, !ref.isEmpty {
                        Text("\u{00B7}")
                            .foregroundStyle(palette.textMuted)
                        Text(ref)
                            .font(BPFont.caption)
                            .foregroundStyle(palette.accent)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
