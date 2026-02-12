import SwiftUI

struct BibleSearchView: View {
    @Bindable var viewModel: BibleSearchViewModel
    let onSelectResult: (BibleBook, Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                searchField

                Divider().overlay(palette.border)

                // Content
                if hasAnyResults {
                    resultsList
                } else if viewModel.isSearching {
                    searchingState
                } else if let error = viewModel.errorMessage {
                    errorState(message: error)
                } else {
                    emptyState
                }
            }
            .background(palette.background)
            .navigationTitle("Search Bible")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
            }
            .onAppear {
                isSearchFocused = true
            }
        }
        .presentationBackground(palette.background)
    }

    private var hasAnyResults: Bool {
        !viewModel.bookMatches.isEmpty || !viewModel.results.isEmpty
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(palette.textMuted)

            TextField("Book, chapter, or verse...", text: $viewModel.query)
                .font(BPFont.body)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { viewModel.searchDebounced() }
                .onChange(of: viewModel.query) { _, _ in
                    viewModel.searchDebounced()
                }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(palette.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(palette.surface)
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Book navigation matches
                if !viewModel.bookMatches.isEmpty {
                    ForEach(viewModel.bookMatches) { match in
                        Button {
                            onSelectResult(match.book, match.chapter ?? 1, match.verseNumber ?? 1)
                            dismiss()
                        } label: {
                            bookMatchRow(match)
                        }
                    }

                    // Divider between sections
                    if !viewModel.results.isEmpty {
                        Divider()
                            .overlay(palette.border)
                            .padding(.vertical, 4)
                    }
                }

                // Verse text results
                if !viewModel.results.isEmpty {
                    Text("\(viewModel.totalResults) verse\(viewModel.totalResults == 1 ? "" : "s")")
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    ForEach(viewModel.results) { result in
                        Button {
                            onSelectResult(result.book, result.chapter, result.verseNumber)
                            dismiss()
                        } label: {
                            resultRow(result)
                        }
                    }

                    // Load more
                    if viewModel.hasMoreResults {
                        Button {
                            viewModel.loadMore()
                        } label: {
                            HStack {
                                if viewModel.isSearching {
                                    ProgressView()
                                        .tint(palette.accent)
                                        .scaleEffect(0.8)
                                }
                                Text("Load More")
                                    .font(BPFont.button)
                                    .foregroundStyle(palette.accent)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                    }
                }

                // Searching indicator when book matches exist but verses still loading
                if !viewModel.bookMatches.isEmpty && viewModel.results.isEmpty && viewModel.isSearching {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(palette.accent)
                            .scaleEffect(0.7)
                        Text("Searching verses...")
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Book Match Row

    private func bookMatchRow(_ match: BookNavigationMatch) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(match.displayTitle)
                    .font(BPFont.button)
                    .foregroundStyle(palette.textPrimary)

                Text(match.subtitle)
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Verse Result Row

    private func resultRow(_ result: BibleSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.reference)
                .font(BPFont.button)
                .foregroundStyle(palette.accent)

            highlightedText(result.text, query: viewModel.query)
                .font(BPFont.body)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func highlightedText(_ text: String, query: String) -> Text {
        let lowercaseText = text.lowercased()
        let lowercaseQuery = query.lowercased().trimmingCharacters(in: .whitespaces)

        guard !lowercaseQuery.isEmpty,
              let range = lowercaseText.range(of: lowercaseQuery) else {
            return Text(text)
        }

        let before = String(text[text.startIndex..<range.lowerBound])
        let match = String(text[range])
        let after = String(text[range.upperBound...])

        return Text(before) + Text(match).bold() + Text(after)
    }

    // MARK: - States

    private var searchingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(palette.accent)
            Text("Searching...")
                .font(BPFont.body)
                .foregroundStyle(palette.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(palette.accent)

            Text("Search Failed")
                .font(BPFont.headingSmall)
                .foregroundStyle(palette.textPrimary)

            Text(message)
                .font(BPFont.body)
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)

            Button {
                viewModel.searchDebounced()
            } label: {
                Text("Try Again")
                    .font(BPFont.button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(palette.accent))
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(palette.accent)

            if viewModel.query.trimmingCharacters(in: .whitespaces).count >= 3 {
                Text("No Results Found")
                    .font(BPFont.headingSmall)
                    .foregroundStyle(palette.textPrimary)

                Text("Try a different search term.")
                    .font(BPFont.body)
                    .foregroundStyle(palette.textMuted)
            } else {
                Text("Search the Bible")
                    .font(BPFont.headingSmall)
                    .foregroundStyle(palette.textPrimary)

                Text("Search by book name, reference,\nor keyword.")
                    .font(BPFont.body)
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
