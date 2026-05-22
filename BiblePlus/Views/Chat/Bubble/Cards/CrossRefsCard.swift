import SwiftUI

struct CrossRefsCard: View {
    let refs: [(reference: String, quote: String)]
    let onScriptureTap: ((String, Int, Int) -> Void)?

    @Environment(\.bpPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 0) {
                ForEach(Array(refs.enumerated()), id: \.offset) { idx, ref in
                    CrossRefRow(
                        reference: ref.reference,
                        quote: ref.quote,
                        onScriptureTap: onScriptureTap
                    )
                    if idx < refs.count - 1 {
                        Divider()
                            .background(palette.border.opacity(0.4))
                            .padding(.horizontal, 14)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.surfaceElevated.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
            )
        }
        .padding(.vertical, 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.accent.opacity(0.75))
            Text("CROSS-REFERENCES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.75))
            Spacer(minLength: 0)
        }
    }
}

private struct CrossRefRow: View {
    let reference: String
    let quote: String
    let onScriptureTap: ((String, Int, Int) -> Void)?

    @Environment(\.bpPalette) private var palette

    var body: some View {
        Button {
            if let (bookName, chapter, verse) = ScriptureParser.parseReference(reference) {
                onScriptureTap?(bookName, chapter, verse)
                HapticService.lightImpact()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(palette.accent.opacity(0.10))
                    )
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reference)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)

                    Text(quote)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(palette.textPrimary.opacity(0.88))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
