import SwiftUI

struct JournalTabView: View {
    @Bindable var viewModel: SavedViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showComposeSheet = false

    var body: some View {
        let items = viewModel.journalEntries
        VStack(spacing: 0) {
            filterChips

            if items.isEmpty {
                emptyJournal
            } else {
                List {
                    ForEach(items) { entry in
                        NavigationLink {
                            PrayerEntryDetailView(entry: entry, viewModel: viewModel)
                        } label: {
                            PrayerEntryRow(entry: entry, palette: palette)
                        }
                    }
                    .onDelete { offsets in
                        HapticService.notification(.warning)
                        for index in offsets {
                            viewModel.deletePrayerEntry(items[index])
                        }
                    }
                    .listRowBackground(palette.surface)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(palette.background)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showComposeSheet = true
                HapticService.lightImpact()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(palette.accent)
                    )
                    .shadow(color: palette.accent.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showComposeSheet) {
            PrayerComposeSheet(viewModel: viewModel, editingEntry: nil)
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SavedViewModel.JournalFilter.allCases, id: \.self) { filter in
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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
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
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "book.pages")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(palette.accent)

            Text("Your Prayer Journal")
                .font(BPFont.headingSmall)
                .foregroundStyle(palette.textPrimary)

            Text("Write your first prayer.\nPour out your heart to God.")
                .font(BPFont.body)
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)

            Button {
                HapticService.lightImpact()
                showComposeSheet = true
            } label: {
                Text("Write a Prayer")
                    .font(BPFont.button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(palette.accent)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }
}

// MARK: - Prayer Entry Row

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
