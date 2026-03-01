import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Binding var pendingConversation: PendingConversation?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: ConversationListViewModel?
    @State private var navigationPath = NavigationPath()
    @State private var pendingContext: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let vm = viewModel {
                    ConversationListContent(
                        viewModel: vm,
                        onNewConversation: { startNewConversation() },
                        onSelectConversation: { navigationPath.append($0.id) },
                        onPromptTapped: { startNewConversationWithPrompt($0) }
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
                        ZStack {
                            Circle()
                                .fill(palette.accent.opacity(0.04))
                                .frame(width: 40, height: 40)

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
            }
            .navigationDestination(for: UUID.self) { conversationId in
                ChatView(conversationId: conversationId, initialContext: consumePendingContext())
                    .onDisappear {
                        viewModel?.loadConversations()
                    }
            }
        }
        .onChange(of: pendingConversation?.conversationId) { _, newValue in
            guard let pending = pendingConversation else { return }
            pendingContext = pending.context
            pendingConversation = nil
            viewModel?.loadConversations()
            navigationPath.append(pending.conversationId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { notification in
            guard let idString = notification.userInfo?["conversationId"] as? String,
                  let conversationId = UUID(uuidString: idString) else { return }
            pendingContext = notification.userInfo?["context"] as? String
            viewModel?.loadConversations()
            navigationPath.append(conversationId)
        }
    }

    private func startNewConversation() {
        guard let vm = viewModel else { return }
        let conversation = vm.createNewConversation()
        navigationPath.append(conversation.id)
        HapticService.lightImpact()
    }

    private func startNewConversationWithPrompt(_ prompt: String) {
        pendingContext = prompt
        startNewConversation()
    }

    private func consumePendingContext() -> String? {
        defer { pendingContext = nil }
        return pendingContext
    }
}

// MARK: - Inner Content View

private struct ConversationListContent: View {
    @Bindable var viewModel: ConversationListViewModel
    let onNewConversation: () -> Void
    let onSelectConversation: (Conversation) -> Void
    let onPromptTapped: (String) -> Void
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    var body: some View {
        if viewModel.conversations.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                // Summary pill
                summaryBar

                // Pinned section
                if !viewModel.pinnedConversations.isEmpty {
                    sectionHeader(title: "PINNED", icon: "pin.fill")

                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.pinnedConversations) { conversation in
                            conversationButton(conversation, isPinned: true)
                        }
                    }
                }

                // Recent section
                if !viewModel.unpinnedConversations.isEmpty {
                    if !viewModel.pinnedConversations.isEmpty {
                        sectionHeader(title: "RECENT", icon: nil)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(Array(viewModel.unpinnedConversations.enumerated()), id: \.element.id) { index, conversation in
                            conversationButton(conversation, isPinned: false)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 10)
                                .animation(BPAnimation.spring.delay(0.1 + Double(min(index, 8)) * 0.03), value: appeared)
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

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.accent)

            Text("\(viewModel.conversations.count) \(viewModel.conversations.count == 1 ? "conversation" : "conversations")")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(palette.accent.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(palette.accent.opacity(0.1), lineWidth: 0.5)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .opacity(appeared ? 1 : 0)
        .animation(BPAnimation.spring.delay(0.05), value: appeared)
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String?) -> some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(palette.accent.opacity(0.08))
                    )
            }

            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            Rectangle()
                .fill(palette.border.opacity(0.1))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    // MARK: - Conversation Button

    private func conversationButton(_ conversation: Conversation, isPinned: Bool) -> some View {
        Button {
            HapticService.selection()
            onSelectConversation(conversation)
        } label: {
            ConversationCard(
                conversation: conversation,
                preview: viewModel.lastMessagePreview(for: conversation),
                palette: palette,
                colorScheme: colorScheme
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .contextMenu {
            Button {
                viewModel.togglePin(conversation)
            } label: {
                Label(
                    conversation.isPinned ? "Unpin" : "Pin",
                    systemImage: conversation.isPinned ? "pin.slash.fill" : "pin.fill"
                )
            }
            Button(role: .destructive) {
                viewModel.deleteConversation(conversation)
                HapticService.notification(.warning)
            } label: {
                Label("Delete Conversation", systemImage: "trash")
            }
        }
    }

    // MARK: - Top Gold Gradient

    private var topGoldGradient: some View {
        let tint: Color = colorScheme == .dark
            ? palette.accent
            : Color(red: 0.65, green: 0.48, blue: 0.25)
        let strength: CGFloat = colorScheme == .dark ? 0.20 : 0.28
        let bg = palette.background

        return LinearGradient(
            stops: [
                .init(color: bg.blend(with: tint, amount: strength), location: 0.0),
                .init(color: bg.blend(with: tint, amount: strength * 0.9), location: 0.12),
                .init(color: bg.blend(with: tint, amount: strength * 0.7), location: 0.25),
                .init(color: bg.blend(with: tint, amount: strength * 0.45), location: 0.40),
                .init(color: bg.blend(with: tint, amount: strength * 0.15), location: 0.55),
                .init(color: bg, location: 0.65),
                .init(color: bg, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon with layered rings
            ZStack {
                Circle()
                    .stroke(palette.accent.opacity(0.06), lineWidth: 0.5)
                    .frame(width: 170, height: 170)

                Circle()
                    .fill(palette.accent.opacity(0.04))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(palette.accent.opacity(0.06))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(palette.surfaceElevated)
                    .frame(width: 72, height: 72)
                    .shadow(color: palette.accent.opacity(0.1), radius: 12, y: 4)
                    .overlay(
                        Circle()
                            .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
                    )

                Image(systemName: "sparkle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(palette.accent)

                // Small floating accent icon
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent.opacity(0.4))
                    .offset(x: 38, y: -26)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(BPAnimation.spring.delay(0.05), value: appeared)

            Spacer().frame(height: 28)

            // Header
            Text("Start a new conversation")
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(BPAnimation.spring.delay(0.1), value: appeared)

            Spacer().frame(height: 10)

            // Subtitle
            Text("Your personal guide for scripture,\nprayer, and reflection")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(BPAnimation.spring.delay(0.15), value: appeared)

            Spacer().frame(height: 32)

            // New Conversation button
            Button {
                HapticService.lightImpact()
                onNewConversation()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
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
                                colors: [palette.accent, palette.accent.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: palette.accent.opacity(0.25), radius: 8, y: 4)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.2), value: appeared)

            Spacer().frame(height: 40)

            // Inspiring verse
            VStack(spacing: 6) {
                Text("\u{201C}\(inspiringVerse.text)\u{201D}")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text(inspiringVerse.reference)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(palette.accent.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)
            .animation(BPAnimation.spring.delay(0.3), value: appeared)

            Spacer()
        }
        .padding(.horizontal, 24)
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

    private var inspiringVerse: (text: String, reference: String) {
        let verses: [(String, String)] = [
            ("Trust in the Lord with all thine heart; and lean not unto thine own understanding.", "Proverbs 3:5"),
            ("Be still, and know that I am God.", "Psalm 46:10"),
            ("Cast thy burden upon the Lord, and he shall sustain thee.", "Psalm 55:22"),
            ("The Lord is my shepherd; I shall not want.", "Psalm 23:1"),
            ("I can do all things through Christ which strengtheneth me.", "Philippians 4:13"),
            ("Come unto me, all ye that labour and are heavy laden, and I will give you rest.", "Matthew 11:28"),
            ("For God so loved the world, that he gave his only begotten Son.", "John 3:16"),
        ]
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let verse = verses[dayIndex % verses.count]
        return (text: verse.0, reference: verse.1)
    }
}

// MARK: - Conversation Card

private struct ConversationCard: View {
    let conversation: Conversation
    let preview: String
    let palette: BPColorPalette
    let colorScheme: ColorScheme

    private var cardIcon: String {
        if let character = conversation.character {
            return character.icon
        }
        return "sparkle"
    }

    private var iconAccent: Color {
        if conversation.isPinned { return palette.accent }
        if conversation.character != nil { return Color(hex: "9B7BD5") }
        return palette.accent
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon with layered depth
            ZStack {
                Circle()
                    .fill(iconAccent.opacity(0.08))
                    .frame(width: 46, height: 46)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [iconAccent.opacity(0.18), iconAccent.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: cardIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconAccent)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(palette.accent)
                            .rotationEffect(.degrees(-15))
                    }

                    Text(conversation.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)

                    if let mode = conversation.mode {
                        Text(mode.displayName)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(palette.accent.opacity(0.1))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
                            )
                    }

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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.textMuted.opacity(0.4))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    conversation.isPinned
                        ? palette.accent.opacity(0.15)
                        : palette.border.opacity(0.1),
                    lineWidth: conversation.isPinned ? 1 : 0.5
                )
        )
        // Left accent bar for pinned conversations
        .overlay(alignment: .leading) {
            if conversation.isPinned {
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(palette.accent.opacity(0.5))
                .frame(width: 3)
            }
        }
    }
}
