import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 26/255, green: 25/255, blue: 21/255)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}
