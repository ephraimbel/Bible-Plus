import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.85
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(hex: "FAF8F4")
                .ignoresSafeArea()

            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}
