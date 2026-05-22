import SwiftUI

struct ActionCard: View {
    let label: String
    let link: String
    let description: String
    let onScriptureTap: ((String, Int, Int) -> Void)?

    @Environment(\.bpPalette) private var palette

    var body: some View {
        Button {
            handleActionLink(link)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if !description.isEmpty {
                        Text(description)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(2)
                    }
                    Text(label)
                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(palette.accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private func handleActionLink(_ link: String) {
        HapticService.lightImpact()
        if link.hasPrefix("bible://") {
            let parts = link.replacingOccurrences(of: "bible://", with: "").replacingOccurrences(of: "+", with: " ")
            let components = parts.components(separatedBy: " ")
            if components.count >= 2, let chapter = Int(components.last ?? "") {
                let bookName = components.dropLast().joined(separator: " ")
                onScriptureTap?(bookName, chapter, 0)
            }
        } else if link.hasPrefix("sanctuary://") {
            NotificationCenter.default.post(name: .init("openSanctuary"), object: nil)
        } else if link.hasPrefix("plan://") {
            NotificationCenter.default.post(name: .init("openPlans"), object: nil)
        }
    }
}
