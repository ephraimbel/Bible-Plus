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
    /// Optional message to scroll to once the destination ChatView mounts.
    /// Set when a `.navigateToConversation` notification arrives carrying
    /// a `messageId` (e.g. tapping a saved AI reply on the Saved page).
    @State private var pendingMessageId: UUID?

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
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                        .tracking(0.3)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewConversation()
                    } label: {
                        ComposeGemButton(palette: palette, colorScheme: colorScheme)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .navigationDestination(for: UUID.self) { conversationId in
                ChatView(
                    conversationId: conversationId,
                    initialContext: consumePendingContext(),
                    initialMessageId: consumePendingMessageId()
                )
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
            // Optional — set when navigating from a saved chat reply so
            // ChatView can scroll to the original message after load.
            if let msgIdString = notification.userInfo?["messageId"] as? String,
               let msgId = UUID(uuidString: msgIdString) {
                pendingMessageId = msgId
            }
            viewModel?.loadConversations()
            navigationPath.append(conversationId)
        }
    }

    private func consumePendingMessageId() -> UUID? {
        defer { pendingMessageId = nil }
        return pendingMessageId
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
                let groups = viewModel.groupedConversations
                LazyVStack(spacing: 0, pinnedViews: []) {
                    heroHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(BPAnimation.spring.delay(0.05), value: appeared)

                    if !groups.pinned.isEmpty {
                        section(title: "PINNED", icon: "pin.fill", conversations: groups.pinned)
                    }
                    if !groups.today.isEmpty {
                        section(title: "TODAY", icon: nil, conversations: groups.today)
                    }
                    if !groups.thisWeek.isEmpty {
                        section(title: "THIS WEEK", icon: nil, conversations: groups.thisWeek)
                    }
                    if !groups.earlier.isEmpty {
                        section(title: "EARLIER", icon: nil, conversations: groups.earlier)
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.top, 4)
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

    // MARK: - Hero Header

    private var heroHeader: some View {
        let count = viewModel.conversations.count
        let countLabel = count == 1 ? "1 conversation" : "\(count) conversations"
        let greeting = viewModel.userName.isEmpty
            ? "Ask anything"
            : "Hello, \(viewModel.userName)"

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent.opacity(0.85))
                Text(countLabel.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(palette.accent.opacity(0.85))
            }

            Text(greeting)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)

            Text("Where would you like to begin today?")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textSecondary.opacity(0.85))
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    // MARK: - Section

    @ViewBuilder
    private func section(title: String, icon: String?, conversations: [Conversation]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title, icon: icon)

            VStack(spacing: 12) {
                ForEach(Array(conversations.enumerated()), id: \.element.id) { index, conversation in
                    conversationRow(conversation)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(
                            BPAnimation.spring.delay(0.08 + Double(min(index, 8)) * 0.03),
                            value: appeared
                        )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Section Header (small caps + hairline accent rule)

    private func sectionHeader(_ title: String, icon: String?) -> some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(palette.accent.opacity(0.85))
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.textMuted.opacity(0.95))

            // Hairline gold accent rule fading out to the trailing edge
            LinearGradient(
                colors: [palette.accent.opacity(0.35), palette.accent.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 12)
    }

    // MARK: - Conversation Row

    @ViewBuilder
    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            HapticService.selection()
            onSelectConversation(conversation)
        } label: {
            ConversationRow(
                conversation: conversation,
                preview: viewModel.lastMessagePreview(for: conversation),
                palette: palette
            )
        }
        .buttonStyle(PressableButtonStyle())
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
        let tint = palette.accent
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

// MARK: - Conversation Row (editorial / journal-style)
//
// Replaces the previous chunky `ConversationCard` design. This row treats
// each conversation as a journal entry: serif title, dimmed serif preview,
// small-caps timestamp, no avatar, no chevron, no rounded surface chrome.
// Pinned conversations get a hairline left accent rule. Mode (if any) is
// rendered as small caps next to the timestamp — no pill, no icon.

private struct ConversationRow: View {
    let conversation: Conversation
    let preview: String
    let palette: BPColorPalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Premium gem icon — gold gradient circle with mode/sparkle glyph.
            ConversationGemIcon(
                symbol: gemSymbol,
                palette: palette,
                colorScheme: colorScheme,
                isPinned: conversation.isPinned
            )

            VStack(alignment: .leading, spacing: 6) {
                // Title row: serif title + timestamp pill on the right.
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(conversation.title)
                        .font(.system(size: 16.5, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(formattedTimestamp)
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(palette.accent.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(palette.accent.opacity(colorScheme == .dark ? 0.10 : 0.08))
                        )
                        .overlay(
                            Capsule()
                                .stroke(palette.accent.opacity(0.18), lineWidth: 0.5)
                        )
                }

                // Mode label as small caps
                if let mode = conversation.mode {
                    Text(mode.displayName.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(palette.accent.opacity(0.78))
                }

                // Preview as italic serif — reads as a journal excerpt.
                Text(preview)
                    .font(.system(size: 13.5, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textSecondary.opacity(0.82))
                    .lineSpacing(3)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .overlay(rowBorder)
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06),
            radius: 10,
            x: 0,
            y: 4
        )
        .shadow(
            color: palette.accent.opacity(conversation.isPinned ? 0.10 : 0),
            radius: 14,
            x: 0,
            y: 0
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var gemSymbol: String {
        if conversation.character != nil { return "person.fill" }
        if let mode = conversation.mode { return mode.icon }
        return "sparkle"
    }

    private var rowBackground: some View {
        let base = palette.surfaceElevated.opacity(colorScheme == .dark ? 0.55 : 0.85)
        return RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        base,
                        base.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Subtle gold inner glow at the top edge
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.accent.opacity(colorScheme == .dark ? 0.07 : 0.05),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: conversation.isPinned
                        ? [palette.accent.opacity(0.55), palette.accent.opacity(0.18)]
                        : [
                            palette.accent.opacity(colorScheme == .dark ? 0.22 : 0.18),
                            palette.border.opacity(colorScheme == .dark ? 0.30 : 0.35)
                          ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: conversation.isPinned ? 0.8 : 0.6
            )
    }

    /// Smarter relative timestamp:
    ///   - Today  → time of day, e.g. "9:42 AM"
    ///   - Yesterday → "YESTERDAY"
    ///   - This week → weekday name, e.g. "TUESDAY"
    ///   - Earlier → month + day, e.g. "MAR 12"
    private var formattedTimestamp: String {
        let calendar = Calendar.current
        let date = conversation.updatedAt
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date).uppercased()
        }
        if calendar.isDateInYesterday(date) {
            return "YESTERDAY"
        }
        if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date).uppercased()
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Conversation Gem Icon
//
// A small premium "gem" used as the leading avatar on each conversation row.
// Layered: outer soft halo + gold gradient disc + inner highlight + glyph.
// When the conversation is pinned, an additional pin badge floats top-right.

private struct ConversationGemIcon: View {
    let symbol: String
    let palette: BPColorPalette
    let colorScheme: ColorScheme
    let isPinned: Bool

    var body: some View {
        ZStack {
            // Outer soft halo
            Circle()
                .fill(palette.accent.opacity(colorScheme == .dark ? 0.10 : 0.08))
                .frame(width: 46, height: 46)

            // Gold gradient disc
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.accent.opacity(colorScheme == .dark ? 0.32 : 0.22),
                            palette.accent.opacity(colorScheme == .dark ? 0.18 : 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .overlay(
                    Circle()
                        .stroke(palette.accent.opacity(0.45), lineWidth: 0.6)
                )
                .overlay(
                    // Subtle top highlight
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(colorScheme == .dark ? 0.10 : 0.30), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: 38, height: 38)
                        .blendMode(.plusLighter)
                )

            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accent)

            // Pin badge floats above the gem
            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(palette.accent)
                            .shadow(color: palette.accent.opacity(0.4), radius: 3, y: 1)
                    )
                    .offset(x: 16, y: -16)
            }
        }
        .frame(width: 46, height: 46)
    }
}

// MARK: - Compose Gem Button (toolbar)
//
// Premium gold gem version of the "new conversation" button used in the
// navigation bar. Mirrors the row gem so the visual language stays cohesive.

private struct ComposeGemButton: View {
    let palette: BPColorPalette
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.accent.opacity(colorScheme == .dark ? 0.10 : 0.08))
                .frame(width: 38, height: 38)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.accent.opacity(colorScheme == .dark ? 0.30 : 0.22),
                            palette.accent.opacity(colorScheme == .dark ? 0.16 : 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(palette.accent.opacity(0.5), lineWidth: 0.6)
                )

            Image(systemName: "square.and.pencil")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
        .shadow(color: palette.accent.opacity(0.18), radius: 6, y: 2)
    }
}
