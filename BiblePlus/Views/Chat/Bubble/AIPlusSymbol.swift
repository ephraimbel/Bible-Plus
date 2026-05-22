import SwiftUI

struct AIPlusSymbol: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let armLength = min(size.width, size.height) * 0.48
            let armWidth: CGFloat = max(size.width * 0.14, 1.5)

            var path = Path()

            path.move(to: CGPoint(x: center.x, y: center.y - armLength))
            path.addLine(to: CGPoint(x: center.x + armWidth, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + armLength))
            path.addLine(to: CGPoint(x: center.x - armWidth, y: center.y))
            path.closeSubpath()

            path.move(to: CGPoint(x: center.x - armLength, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + armWidth))
            path.addLine(to: CGPoint(x: center.x + armLength, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y - armWidth))
            path.closeSubpath()

            let gradient = Gradient(colors: [
                Color(red: 1.0, green: 0.84, blue: 0.3),
                Color(red: 0.79, green: 0.66, blue: 0.43)
            ])

            context.fill(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
        }
    }
}
