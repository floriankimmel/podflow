import SwiftUI

/// Laufend-Entdecken-flavored visual language: alpine trail palette over
/// Liquid-Glass materials (design.md — UI Design).
enum Theme {
    /// Trail orange — primary brand accent (sunrise on the ridge).
    static let accent = Color(red: 0.95, green: 0.45, blue: 0.13)
    /// Alpine green — secondary brand tone.
    static let alpine = Color(red: 0.13, green: 0.42, blue: 0.31)

    static func statusColor(_ state: StepState) -> Color {
        switch state {
        case .pending: return .secondary.opacity(0.5)
        case .inProgress: return .blue
        case .done: return .green
        case .failed: return .red
        }
    }

    static func statusLabel(_ state: StepState) -> String {
        switch state {
        case .pending: return "ausstehend"
        case .inProgress: return "läuft"
        case .done: return "fertig"
        case .failed: return "fehlgeschlagen"
        }
    }

    /// Vibrant backdrop the glass panels float on.
    static var backdrop: some View {
        LinearGradient(
            colors: [
                alpine.opacity(0.35),
                accent.opacity(0.18),
                Color(nsColor: .windowBackgroundColor),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

/// Frosted glass panel with a soft specular top edge (Liquid Glass).
struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.08), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
}

/// Glossy primary action button.
struct GlassButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                prominent ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
            .foregroundStyle(prominent ? .white : .primary)
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
