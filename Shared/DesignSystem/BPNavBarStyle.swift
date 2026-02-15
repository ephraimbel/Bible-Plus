import SwiftUI

// MARK: - Custom UIView that configures the nav bar when added to the window

private class NavBarStyleView: UIView {
    var bgColor: UIColor = .clear
    var titleColor: UIColor = .label

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        applyStyle()
        // Retry after sheet presentation animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.applyStyle()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyStyle()
    }

    func applyStyle() {
        guard let navBar = findNavigationBar() else { return }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bgColor
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
        appearance.shadowColor = .clear
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.tintColor = titleColor
    }

    private func findNavigationBar() -> UINavigationBar? {
        var responder: UIResponder? = self
        while let r = responder {
            if let nav = r as? UINavigationController {
                return nav.navigationBar
            }
            responder = r.next
        }
        return nil
    }
}

// MARK: - UIViewRepresentable bridge

private struct NavBarConfiguratorView: UIViewRepresentable {
    let backgroundColor: Color
    let titleColor: Color

    func makeUIView(context: Context) -> NavBarStyleView {
        let view = NavBarStyleView()
        view.isUserInteractionEnabled = false
        view.isHidden = true
        view.bgColor = UIColor(backgroundColor)
        view.titleColor = UIColor(titleColor)
        return view
    }

    func updateUIView(_ uiView: NavBarStyleView, context: Context) {
        uiView.bgColor = UIColor(backgroundColor)
        uiView.titleColor = UIColor(titleColor)
        uiView.applyStyle()
    }
}

extension View {
    /// Apply palette-aware navigation bar styling that works in sheets and tabs.
    func bpNavBarStyle(background: Color, title: Color) -> some View {
        self.background(
            NavBarConfiguratorView(backgroundColor: background, titleColor: title)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
    }
}
