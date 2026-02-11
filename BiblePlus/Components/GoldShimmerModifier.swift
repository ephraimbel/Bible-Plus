import SwiftUI

struct GoldShimmerModifier: ViewModifier {
    @State private var offset: CGFloat = -200

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color(red: 0.85, green: 0.72, blue: 0.45).opacity(0.4), location: 0.3),
                        .init(color: .white.opacity(0.6), location: 0.5),
                        .init(color: Color(red: 0.85, green: 0.72, blue: 0.45).opacity(0.4), location: 0.7),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 80)
                .offset(x: offset)
                .onAppear {
                    withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                        offset = 200
                    }
                }
            )
            .clipped()
    }
}

extension View {
    func goldShimmer() -> some View {
        modifier(GoldShimmerModifier())
    }
}
