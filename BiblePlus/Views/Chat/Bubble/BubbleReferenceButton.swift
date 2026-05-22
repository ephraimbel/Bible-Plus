import SwiftUI

struct BubbleReferenceButton: View {
    let reference: String
    let onScriptureTap: ((String, Int, Int) -> Void)?

    @Environment(\.bpPalette) private var palette

    var body: some View {
        Group {
            if let (bookName, chapter, verse) = ScriptureParser.parseReference(reference) {
                Button {
                    onScriptureTap?(bookName, chapter, verse)
                    HapticService.lightImpact()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 10))
                        Text(reference)
                    }
                    .foregroundStyle(palette.accent)
                }
            } else {
                Text(reference)
                    .foregroundStyle(palette.accent)
            }
        }
    }
}
