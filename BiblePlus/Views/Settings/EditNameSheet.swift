import SwiftUI

struct EditNameSheet: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("What should we call you?")
                        .font(BPFont.headingSmall)
                        .foregroundStyle(palette.textPrimary)

                    Text("This name appears in your feed and prayers.")
                        .font(BPFont.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.top, 8)

                TextField("Your name", text: $vm.editingName)
                    .font(BPFont.body)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(palette.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isFocused ? palette.accent : palette.border, lineWidth: 1)
                    )
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)

                if !vm.editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Hi, \(vm.editingName.trimmingCharacters(in: .whitespacesAndNewlines))!")
                        .font(BPFont.prayerMedium)
                        .foregroundStyle(palette.accent)
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .animation(BPAnimation.spring, value: vm.editingName)
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        vm.saveName()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.accent)
                    .disabled(vm.editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
