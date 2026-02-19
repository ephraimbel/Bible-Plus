import SwiftUI

struct NotificationTopicsView: View {
    @Bindable var vm: SettingsViewModel
    @Binding var showPaywall: Bool
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Choose the topics you'd like to receive throughout your day.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)

                    // Free Topics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FREE")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .padding(.leading, 4)

                        topicSection(topics: NotificationTopic.freeTopics)
                    }

                    // Pro Topics
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("PRO")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.accent)
                                .textCase(.uppercase)
                                .tracking(1.5)

                            Image(systemName: "crown.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(palette.accent)
                        }
                        .padding(.leading, 4)

                        topicSection(topics: NotificationTopic.proTopics)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Notification Topics")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }
            }
        }
    }

    // MARK: - Topic Section Card

    private func topicSection(topics: [NotificationTopic]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                if index > 0 {
                    Divider()
                        .background(palette.border.opacity(0.1))
                        .padding(.leading, 62)
                }
                topicRow(topic)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Topic Row

    private func topicRow(_ topic: NotificationTopic) -> some View {
        let isSelected = vm.profile.selectedNotificationTopics.contains(topic)
        let isLocked = topic.isPro && !vm.profile.isPro

        return Button {
            HapticService.selection()
            if isLocked {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywall = true
                }
            } else {
                vm.toggleNotificationTopic(topic)
            }
        } label: {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: topic.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.accent.opacity(0.08))
                    )

                // Name
                Text(topic.displayName)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(isLocked ? palette.textMuted : palette.textPrimary)

                Spacer()

                if isLocked {
                    // Lock badge
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.textMuted.opacity(0.5))
                } else {
                    // Checkmark toggle
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? palette.accent : palette.textMuted.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
