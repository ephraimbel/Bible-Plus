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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Journal")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
            }
        }
    }
}

// MARK: - Inner Content View

private struct JournalContentView: View {
    @Bindable var viewModel: JournalViewModel
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var showComposeSheet = false
    @State private var appeared = false
    @State private var reflectionPrompt: String?

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            let items = viewModel.journalEntries

            if items.isEmpty {
                emptyJournal
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero section
                        heroSection

                        // Stats strip
                        statsStrip

                        // Filter chips
                        filterChips

                        // Prayer list
                        LazyVStack(spacing: 12) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                                NavigationLink {
                                    PrayerEntryDetailView(entry: entry, viewModel: viewModel)
                                } label: {
                                    JournalEntryCard(entry: entry, palette: palette)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 20)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 10)
                                .animation(BPAnimation.spring.delay(0.25 + Double(min(index, 6)) * 0.04), value: appeared)
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
                        .padding(.top, 8)

                        Spacer().frame(height: 100)
                    }
                }
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
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [palette.accent, palette.accent.opacity(0.75)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: palette.accent.opacity(0.35), radius: 12, y: 6)
                            )
                    }
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(BPAnimation.spring.delay(0.4), value: appeared)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }

            // Answered celebration overlay
            if viewModel.showAnsweredCelebration {
                AnsweredCelebrationView(
                    prayerTitle: viewModel.celebrationPrayerTitle,
                    onDismiss: { viewModel.showAnsweredCelebration = false }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .sheet(isPresented: $showComposeSheet, onDismiss: {
            reflectionPrompt = nil
        }) {
            PrayerComposeSheet(viewModel: viewModel, editingEntry: nil, reflectionPrompt: reflectionPrompt)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openJournalWithReflection)) { notification in
            guard notification.object as? String == "fromContentView" else { return }
            if let prompt = notification.userInfo?["prompt"] as? String {
                reflectionPrompt = prompt
                showComposeSheet = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            // Decorative curly quote
            Text("\u{201C}")
                .font(.system(size: 72, weight: .bold, design: .serif))
                .foregroundStyle(palette.accent.opacity(0.06))
                .offset(x: 4, y: -10)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.accent)
                    Text("DAILY REFLECTION")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                        .tracking(1.0)
                }

                Text(viewModel.dailyReflection)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showComposeSheet = true
                    HapticService.lightImpact()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 12, weight: .medium))
                        Text("Write a Prayer")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
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
                            .shadow(color: palette.accent.opacity(0.25), radius: 6, y: 3)
                    )
                }
                .padding(.top, 2)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(BPAnimation.spring.delay(0.05), value: appeared)
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        let total = viewModel.totalPrayerCount
        let answered = viewModel.answeredPrayerCount
        let unanswered = total - answered

        return HStack(spacing: 0) {
            statPill(
                icon: "book.pages",
                value: "\(total)",
                label: total == 1 ? "prayer" : "prayers",
                color: palette.accent
            )

            if answered > 0 {
                thinDivider

                statPill(
                    icon: "checkmark.seal.fill",
                    value: "\(answered)",
                    label: "answered",
                    color: palette.success
                )
            }

            if unanswered > 0 {
                thinDivider

                statPill(
                    icon: "heart.fill",
                    value: "\(unanswered)",
                    label: "active",
                    color: palette.accent
                )
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.1), value: appeared)
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textPrimary)

            Text(label)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(palette.border.opacity(0.4))
            .frame(width: 0.5, height: 24)
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
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(
                                viewModel.journalFilter == filter ? .white : palette.textSecondary
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    viewModel.journalFilter == filter
                                        ? palette.accent
                                        : palette.surfaceElevated
                                )
                            )
                            .overlay(
                                Capsule().stroke(
                                    viewModel.journalFilter == filter
                                        ? Color.clear
                                        : palette.border.opacity(0.3),
                                    lineWidth: 0.5
                                )
                            )
                    }
                }

                Rectangle()
                    .fill(palette.border.opacity(0.4))
                    .frame(width: 0.5, height: 20)

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
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(
                            viewModel.journalCategoryFilter == category ? .white : palette.textSecondary
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                viewModel.journalCategoryFilter == category
                                    ? palette.accent
                                    : palette.surfaceElevated
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                viewModel.journalCategoryFilter == category
                                    ? Color.clear
                                    : palette.border.opacity(0.3),
                                lineWidth: 0.5
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.15), value: appeared)
    }

    // MARK: - Empty State

    private var emptyJournal: some View {
        VStack(spacing: 28) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 130, height: 130)

                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 96, height: 96)

                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(palette.accent)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(BPAnimation.spring.delay(0.1), value: appeared)

            VStack(spacing: 10) {
                Text("Your Prayer Journal")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("This is your sacred space to pour out\nyour heart, lift up your prayers, and\ncelebrate when God answers.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)
            .animation(BPAnimation.spring.delay(0.2), value: appeared)

            Button {
                HapticService.impact(.medium)
                showComposeSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 14, weight: .medium))
                    Text("Write Your First Prayer")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: palette.accent.opacity(0.3), radius: 10, y: 5)
                )
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)
            .animation(BPAnimation.spring.delay(0.3), value: appeared)

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
        VStack(alignment: .leading, spacing: 12) {
            // Top row: category + date + answered badge
            HStack(spacing: 8) {
                // Category pill
                HStack(spacing: 4) {
                    Image(systemName: entry.category.icon)
                        .font(.system(size: 10, weight: .medium))
                    Text(entry.category.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(palette.accent.opacity(0.1))
                )

                Spacer()

                if entry.isAnswered {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text("Answered")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(palette.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(palette.success.opacity(0.12))
                    )
                }

                Text(entry.createdAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
            }

            // Title
            Text(entry.title)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)

            // Body preview
            if !entry.body.isEmpty {
                Text(entry.body)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .lineSpacing(3)
            }

            // Verse reference
            if let ref = entry.verseReference, !ref.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 10))
                    Text(ref)
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .italic()
                }
                .foregroundStyle(palette.accent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    entry.isAnswered
                        ? palette.success.opacity(0.25)
                        : palette.border.opacity(0.2),
                    lineWidth: 0.5
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
            .fill(
                LinearGradient(
                    colors: entry.isAnswered
                        ? [palette.success, palette.success.opacity(0.5)]
                        : [palette.accent, palette.accent.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
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
