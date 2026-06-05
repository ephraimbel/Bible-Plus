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

            VStack(spacing: 0) {
                ForEach(Array(conversations.enumerated()), id: \.element.id) { index, conversation in
                    if index > 0 {
                        Rectangle()
                            .fill(palette.border.opacity(0.6))
                            .frame(height: 1)
                    }
                    conversationRow(conversation)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(
                            BPAnimation.spring.delay(0.08 + Double(min(index, 8)) * 0.03),
                            value: appeared
                        )
                }
            }
            .padding(.horizontal, 24)
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

            // Emblem — a single glowing gold mark inside a soft halo and one
            // hairline ring. Floating (no disc) so it echoes the Bible✦ star and
            // reads calm and premium rather than busy.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette.accent.opacity(0.12), palette.accent.opacity(0)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 120
                        )
                    )
                    .frame(width: 224, height: 224)

                Circle()
                    .stroke(palette.accent.opacity(0.13), lineWidth: 1)
                    .frame(width: 118, height: 118)

                Image(systemName: "sparkle")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [palette.accent, palette.accent.opacity(0.62)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: palette.accent.opacity(0.30), radius: 12)
                    .shadow(color: palette.accent.opacity(0.16), radius: 26)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.82)
            .animation(BPAnimation.spring.delay(0.05), value: appeared)

            Spacer().frame(height: 30)

            // Gold eyebrow — echoes the welcome screen's "A Sacred Companion".
            Text("YOUR COMPANION")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.8)
                .foregroundStyle(palette.accent.opacity(0.9))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(BPAnimation.spring.delay(0.10), value: appeared)

            Spacer().frame(height: 14)

            // Headline — Baskerville serif, a warm invitation.
            Text("What's on your heart?")
                .font(.custom("Baskerville-Bold", size: 30))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(BPAnimation.spring.delay(0.14), value: appeared)

            Spacer().frame(height: 12)

            // Subtitle — italic serif, simplified to a single calm line.
            Text("Scripture, prayer, or whatever you're carrying.")
                .font(.custom("NewYork-Regular", size: 15))
                .italic()
                .foregroundStyle(palette.textSecondary.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(BPAnimation.spring.delay(0.18), value: appeared)

            Spacer().frame(height: 34)

            // Primary action — clean gold pill, crisp SF semibold label (no
            // rounded face, no "+") with a quiet forward arrow.
            Button {
                HapticService.lightImpact()
                onNewConversation()
            } label: {
                HStack(spacing: 9) {
                    Text("Start a conversation")
                        .font(.system(size: 15.5, weight: .semibold))
                        .tracking(0.3)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: palette.accent.blend(with: .white, amount: 0.16), location: 0),
                                    .init(color: palette.accent, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.18), lineWidth: 0.5)
                        )
                        .shadow(color: palette.accent.opacity(0.28), radius: 12, y: 5)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.22), value: appeared)

            Spacer()

            // Inspiring verse — a quiet editorial footer pinned near the bottom,
            // beneath a hairline. Same serif voice as the rest of the screen.
            VStack(spacing: 10) {
                Capsule()
                    .fill(palette.accent.opacity(0.3))
                    .frame(width: 22, height: 1.5)

                Text("\u{201C}\(inspiringVerse.text)\u{201D}")
                    .font(.custom("NewYork-Regular", size: 13.5))
                    .italic()
                    .foregroundStyle(palette.textSecondary.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text(inspiringVerse.reference)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(palette.accent.opacity(0.6))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .opacity(appeared ? 1 : 0)
            .animation(BPAnimation.spring.delay(0.3), value: appeared)
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
        // A clean, editorial row — no gem, no card chrome. Serif title, a quiet
        // timestamp, an optional mode label, and a dimmed serif preview. The
        // hairline divider between rows (in the section) does the separating.
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(conversation.title)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(formattedTimestamp)
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(palette.textMuted.opacity(0.8))
            }

            if let mode = conversation.mode {
                Text(mode.displayName.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(palette.accent.opacity(0.8))
            }

            Text(preview)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textSecondary.opacity(0.7))
                .lineSpacing(2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
