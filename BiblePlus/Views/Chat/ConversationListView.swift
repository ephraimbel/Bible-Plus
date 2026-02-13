import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @State private var viewModel: ConversationListViewModel?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let vm = viewModel {
                    ConversationListContent(
                        viewModel: vm,
                        onNewConversation: { startNewConversation() },
                        onSelectConversation: { navigationPath.append($0.id) }
                    )
                } else {
                    BPLoadingView().onAppear {
                        viewModel = ConversationListViewModel(modelContext: modelContext)
                    }
                }
            }
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewConversation()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16))
                            .foregroundStyle(palette.accent)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { conversationId in
                ChatView(conversationId: conversationId)
                    .onDisappear {
                        viewModel?.loadConversations()
                    }
            }
        }
    }

    private func startNewConversation() {
        guard let vm = viewModel else { return }
        let conversation = vm.createNewConversation()
        navigationPath.append(conversation.id)
        HapticService.lightImpact()
    }
}

// MARK: - Inner Content View

private struct ConversationListContent: View {
    @Bindable var viewModel: ConversationListViewModel
    let onNewConversation: () -> Void
    let onSelectConversation: (Conversation) -> Void
    @Environment(\.bpPalette) private var palette

    var body: some View {
        if viewModel.conversations.isEmpty {
            emptyState
        } else {
            List {
                ForEach(viewModel.conversations) { conversation in
                    Button {
                        HapticService.selection()
                        onSelectConversation(conversation)
                    } label: {
                        ConversationRow(
                            title: conversation.title,
                            preview: viewModel.lastMessagePreview(for: conversation),
                            date: conversation.updatedAt
                        )
                    }
                    .listRowBackground(palette.background)
                }
                .onDelete { indexSet in
                    HapticService.notification(.warning)
                    for index in indexSet {
                        viewModel.deleteConversation(viewModel.conversations[index])
                    }
                }
            }
            .listStyle(.plain)
            .background(palette.background)
            .scrollContentBackground(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(palette.accent)

            Text("Start a conversation")
                .font(BPFont.prayerSmall)
                .foregroundStyle(palette.textPrimary)

            Text("Ask about Scripture, request prayer,\nor just talk through what's on your heart.")
                .font(BPFont.body)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                HapticService.lightImpact()
                onNewConversation()
            } label: {
                Text("New Conversation")
                    .font(BPFont.button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(palette.accent)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(palette.background)
    }
}
