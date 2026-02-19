import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Ask")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewConversation()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(palette.accent.opacity(0.1))
                            )
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
    @State private var appeared = false

    var body: some View {
        if viewModel.conversations.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                // Summary
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.accent)
                    Text("\(viewModel.conversations.count) \(viewModel.conversations.count == 1 ? "conversation" : "conversations")")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .opacity(appeared ? 1 : 0)
                .animation(BPAnimation.spring.delay(0.05), value: appeared)

                LazyVStack(spacing: 10) {
                    ForEach(Array(viewModel.conversations.enumerated()), id: \.element.id) { index, conversation in
                        Button {
                            HapticService.selection()
                            onSelectConversation(conversation)
                        } label: {
                            ConversationCard(
                                conversation: conversation,
                                preview: viewModel.lastMessagePreview(for: conversation),
                                palette: palette
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(BPAnimation.spring.delay(0.1 + Double(min(index, 8)) * 0.03), value: appeared)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteConversation(conversation)
                                HapticService.notification(.warning)
                            } label: {
                                Label("Delete Conversation", systemImage: "trash")
                            }
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
            .background(topGoldGradient)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(BPAnimation.spring) {
                        appeared = true
                    }
                }
            }
        }
    }

    // MARK: - Top Gold Gradient

    private var topGoldGradient: some View {
        ZStack(alignment: .top) {
            palette.background

            LinearGradient(
                stops: [
                    .init(color: palette.accent.opacity(0.08), location: 0),
                    .init(color: palette.accent.opacity(0.03), location: 0.35),
                    .init(color: .clear, location: 0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 88, height: 88)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: palette.accent.opacity(0.3), radius: 8, y: 4)

                    Image(systemName: "sparkle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(BPAnimation.spring.delay(0.1), value: appeared)

            VStack(spacing: 10) {
                Text("Start a Conversation")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("Ask about Scripture, request prayer,\nor talk through what\u{2019}s on your heart.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)
            .animation(BPAnimation.spring.delay(0.2), value: appeared)

            Button {
                HapticService.lightImpact()
                onNewConversation()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("New Conversation")
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
                        .shadow(color: palette.accent.opacity(0.3), radius: 8, y: 4)
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
        .background(topGoldGradient)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - Conversation Card

private struct ConversationCard: View {
    let conversation: Conversation
    let preview: String
    let palette: BPColorPalette

    var body: some View {
        HStack(spacing: 14) {
            // Sparkle icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [palette.accent.opacity(0.15), palette.accent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)

                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(conversation.updatedAt, style: .relative)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }

                Text(preview)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .lineSpacing(2)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
        )
    }
}
