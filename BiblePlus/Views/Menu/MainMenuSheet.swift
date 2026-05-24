import SwiftUI
import SwiftData

// MARK: - Main Menu Sheet
//
// Replaces the tab bar's "everything else" surfaces. Presented from the
// home top-bar profile avatar. Lists the six surfaces a user could
// otherwise reach via tabs: Conversation History, Saved, Progress,
// Reading Plans, Sanctuary, Settings.
//
// Each row dismisses the sheet then posts a notification — ContentView's
// NotificationRouter (or HomeContentView, for sheet/cover destinations)
// handles the actual navigation. The DispatchQueue delay lets the sheet
// dismiss animation finish first so the navigation push isn't fighting
// the sheet's slide-down for the same frames.
struct MainMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        VStack(spacing: 0) {
            grabber
                .padding(.top, 8)

            profileHeader
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

            Divider()
                .background(palette.border.opacity(0.4))

            menuList

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Grabber

    private var grabber: some View {
        Capsule()
            .fill(palette.border.opacity(0.45))
            .frame(width: 38, height: 4)
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: 14) {
            avatarLarge

            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.firstName.isEmpty == false ? profile!.firstName : "Welcome")
                    .font(.custom("Georgia-Bold", size: 22))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                subscriptionBadge
            }

            Spacer(minLength: 0)
        }
    }

    private var avatarLarge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 54, height: 54)

            if let data = profile?.profileImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
            } else {
                Text((profile?.firstName.prefix(1) ?? "?").uppercased())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private var subscriptionBadge: some View {
        let isPro = profile?.isPro == true
        return HStack(spacing: 4) {
            Image(systemName: isPro ? "crown.fill" : "sparkle")
                .font(.system(size: 9, weight: .semibold))
            Text(isPro ? "Pro" : "Free")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(isPro ? palette.accent : palette.textMuted)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(isPro ? palette.accent.opacity(0.12) : palette.surface.opacity(0.6))
        )
        .overlay(
            Capsule()
                .stroke(isPro ? palette.accent.opacity(0.35) : palette.border.opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - Menu List

    private var menuList: some View {
        VStack(spacing: 0) {
            menuRow(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Conversation History",
                subtitle: "Past AI chats"
            ) {
                fireAfterDismiss(.switchToAskTab)
            }

            divider

            menuRow(
                icon: "bookmark.fill",
                title: "Saved",
                subtitle: "Verses, prayers, devotionals"
            ) {
                fireAfterDismiss(.switchToSavedTab)
            }

            divider

            menuRow(
                icon: "flame.fill",
                title: "My Progress",
                subtitle: "Streak, weekly activity"
            ) {
                fireAfterDismiss(.showProgressFromWidget)
            }

            divider

            menuRow(
                icon: "book.pages.fill",
                title: "Reading Plans",
                subtitle: "Browse and continue plans"
            ) {
                fireAfterDismiss(.showPlansFromWidget)
            }

            divider

            menuRow(
                icon: "moon.stars.fill",
                title: "Sanctuary",
                subtitle: "Soundscapes for prayer"
            ) {
                fireAfterDismiss(.openSanctuaryFromWidget)
            }

            divider

            menuRow(
                icon: "gearshape.fill",
                title: "Settings",
                subtitle: "Profile, preferences"
            ) {
                fireAfterDismiss(.switchToSettingsTab)
            }
        }
        .padding(.top, 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.border.opacity(0.25))
            .frame(height: 0.5)
            .padding(.leading, 24 + 36 + 14)
    }

    private func menuRow(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(palette.accent.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Georgia", size: 16))
                        .foregroundStyle(palette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dismiss + Fire

    /// Dismisses the sheet, then fires the notification after the slide-
    /// down animation has had a chance to settle. Avoids the navigation
    /// push fighting the sheet dismiss for the same frames.
    private func fireAfterDismiss(_ name: Notification.Name, userInfo: [AnyHashable: Any]? = nil) {
        HapticService.lightImpact()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
        }
    }
}
