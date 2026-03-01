import SwiftUI

enum AppTheme {
    static let screenBackground = LinearGradient(
        colors: [
            Color(red: 0.97, green: 0.99, blue: 1.0),
            Color(red: 0.95, green: 0.98, blue: 0.96)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = LinearGradient(
        colors: [
            Color.white,
            Color(red: 0.98, green: 0.99, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryButton = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.24, blue: 0.35),
            Color(red: 0.06, green: 0.43, blue: 0.46)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

private struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 8)
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }
}
