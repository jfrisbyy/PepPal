import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ScalePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle { ScaleButtonStyle() }
}

extension ButtonStyle where Self == ScalePrimaryButtonStyle {
    static var scalePrimary: ScalePrimaryButtonStyle { ScalePrimaryButtonStyle() }
}
