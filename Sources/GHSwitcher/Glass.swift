import SwiftUI

private struct GlassStyleKey: EnvironmentKey {
    static let defaultValue: GlassStyle = .clear
}

extension EnvironmentValues {
    var glassStyle: GlassStyle {
        get { self[GlassStyleKey.self] }
        set { self[GlassStyleKey.self] = newValue }
    }
}

/// Superfície de Liquid Glass no estilo da Central de Controle: vidro escuro e translúcido,
/// com o fundo atravessando. Antes do macOS 26 usa um material equivalente.
private struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let tint: Color?
    @Environment(\.glassStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    /// Véu que escurece o vidro `.clear`, como na Central de Controle.
    private var dim: Color {
        colorScheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.18)
    }

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(tint.map { shape.fill($0) })
                .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        let base: Glass = style == .clear ? .clear : .regular
        return base.tint(tint ?? (style == .clear ? dim : nil)).interactive(interactive)
    }
}

extension View {
    func glassSurface<S: Shape>(_ shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassSurface(shape: shape, interactive: interactive, tint: tint))
    }
}

struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 14
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
