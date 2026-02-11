import SwiftUI

struct NameInputView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.bpPalette) private var palette
    @FocusState private var isNameFocused: Bool
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            VStack(spacing: 12) {
                Text("What should we\ncall you?")
                    .font(BPFont.headingMedium)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("We'll use your name to make every prayer,\nevery verse, and every conversation feel personal.")
                    .font(BPFont.reference)
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(showContent ? 1 : 0)

            Spacer().frame(height: 40)

            // Live preview
            Group {
                if viewModel.firstName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Good morning...")
                        .font(BPFont.prayerMedium)
                        .foregroundStyle(palette.textMuted)
                } else {
                    Text("Good morning, \(viewModel.firstName.trimmingCharacters(in: .whitespaces)).")
                        .font(BPFont.prayerMedium)
                        .foregroundStyle(palette.accent)
                    + Text("\nLet's seek God together.")
                        .font(BPFont.prayerSmall)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .multilineTextAlignment(.center)
            .animation(BPAnimation.spring, value: viewModel.firstName)
            .frame(height: 70)

            Spacer().frame(height: 32)

            // Text field
            TextField("Your first name", text: $viewModel.firstName)
                .font(BPFont.headingSmall)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isNameFocused
                                ? palette.accent
                                : palette.border,
                            lineWidth: isNameFocused ? 2 : 1
                        )
                )
                .padding(.horizontal, 40)
                .focused($isNameFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .onSubmit {
                    if viewModel.canProceed {
                        viewModel.goNext()
                    }
                }

            Spacer()

            // Continue button
            GoldButton(
                title: "Continue",
                isEnabled: viewModel.canProceed,
                action: { viewModel.goNext() }
            )
            .padding(.horizontal, 32)

            Spacer().frame(height: 40)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isNameFocused = false
        }
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true
            }
        }
    }
}
