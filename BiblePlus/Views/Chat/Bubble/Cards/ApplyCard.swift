import SwiftUI

struct ApplyCard: View {
    let title: String
    let items: [String]

    @Environment(\.bpPalette) private var palette
    @State private var appeared = false

    private var headerText: String {
        title.isEmpty ? "THIS WEEK" : title.uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent.opacity(0.8))
                Text(headerText)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(palette.accent.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    applyRow(index: index, text: item)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated.opacity(0.4))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        )
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(palette.accent.opacity(0.3))
            .frame(width: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.vertical, 6)
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private func applyRow(index: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(palette.accent.opacity(0.5), lineWidth: 1)
                    .frame(width: 20, height: 20)
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent.opacity(0.9))
            }
            .padding(.top, 1)

            Text(text)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 4)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.85)
                .delay(0.08 * Double(index)),
            value: appeared
        )
    }
}
