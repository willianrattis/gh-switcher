import AppKit
import SwiftUI

/// Grade da Central de Controle: unidade de 64pt e espaço de 12pt (largura de 4 unidades).
private enum Grid {
    static let unit: CGFloat = 64
    static let gap: CGFloat = 12
    static let width: CGFloat = unit * 4 + gap * 3
    static let wideTile: CGFloat = unit * 2 + gap
    static let iconCircle: CGFloat = 38
}

/// Blocos de Liquid Glass soltos, sem painel por trás.
struct PanelView: View {
    @ObservedObject var store: AccountStore
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var presentation: PanelPresentation
    @State private var copied = false

    var body: some View {
        GlassGroup {
            VStack(spacing: Grid.gap) {
                header

                ForEach(store.accountsByHost, id: \.host) { group in
                    if store.accountsByHost.count > 1 {
                        SectionTitle(group.host)
                    }
                    ForEach(group.accounts) { account in
                        AccountTile(account: account,
                                    isSwitching: store.switchingID == account.id,
                                    isLocked: store.isBusy) {
                            Haptics.tap()
                            Task { await store.switchTo(account) }
                        }
                    }
                }

                if let message = store.errorMessage ?? loginItem.errorMessage {
                    ErrorTile(message: message)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }

                HStack(spacing: Grid.gap) {
                    RoundControl(symbol: "arrow.clockwise",
                                 help: "Atualizar",
                                 isSpinning: store.isRefreshing) {
                        Haptics.tap()
                        Task { await store.userRefresh() }
                    }
                    .disabled(store.isRefreshing)

                    RoundControl(symbol: copied ? "checkmark" : "doc.on.doc",
                                 help: "Copiar login ativo",
                                 isSpinning: false) {
                        Haptics.tap()
                        store.copyActiveLogin()
                        withAnimation(Motion.snappy) { copied = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            withAnimation(Motion.snappy) { copied = false }
                        }
                    }
                    .disabled(store.activeAccount == nil)

                    ToggleTile(symbol: "power",
                               title: "Abrir no login",
                               isOn: loginItem.isEnabled) {
                        Haptics.tap()
                        withAnimation(Motion.snappy) { loginItem.toggle() }
                    }
                }

                Button("Sair do GH Switcher") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(CapsuleGlassButtonStyle())
                    .keyboardShortcut("q")
            }
            .frame(width: Grid.width)
        }
        .animation(Motion.snappy, value: store.accounts)
        .animation(Motion.snappy, value: store.errorMessage)
        .scaleEffect(presentation.isShown ? 1 : 0.94, anchor: .top)
        .opacity(presentation.isShown ? 1 : 0)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(nsImage: GitHubMark.image(size: 13))
                .renderingMode(.template)
                .foregroundStyle(.primary)
            Text(store.activeAccount.map { "Conta ativa: \($0.login)" } ?? "Nenhuma conta ativa")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
        .glassSurface(Capsule())
    }
}

// MARK: - Componentes

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
    }
}

/// Círculo de ícone da Central de Controle: azul preenchido quando ligado.
private struct IconCircle: View {
    let symbol: String
    let isOn: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .frame(width: Grid.iconCircle, height: Grid.iconCircle)
            .background(Circle().fill(isOn ? Color.accentColor : Color.primary.opacity(0.1)))
            .animation(Motion.snappy, value: isOn)
    }
}

private struct AccountTile: View {
    let account: GHAccount
    let isSwitching: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if !account.active && account.isValid && !isLocked { action() }
        } label: {
            HStack(spacing: 12) {
                IconCircle(symbol: account.isValid ? "person.fill" : "exclamationmark",
                           isOn: account.active)
                VStack(alignment: .leading, spacing: 1) {
                    Text(account.login)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
                Group {
                    if isSwitching {
                        ProgressView().controlSize(.small)
                    } else if account.active {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 18)
            }
            .padding(.leading, 13)
            .padding(.trailing, 16)
            .frame(width: Grid.width, height: Grid.unit)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .glassSurface(Capsule(), interactive: !account.active)
        .help(account.active ? "Conta ativa" : "Ativar \(account.login)")
        .accessibilityAddTraits(account.active ? .isSelected : [])
    }

    private var subtitle: String {
        if isSwitching { return "Ativando…" }
        if !account.isValid { return "Precisa de login no terminal" }
        let source = account.host == "github.com" ? "GitHub" : account.host
        return account.active ? "Ativa · \(source)" : source
    }
}

private struct RoundControl: View {
    let symbol: String
    let help: String
    let isSpinning: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.primary)
                .contentTransition(.symbolEffectIfAvailable)
                .spinning(isSpinning)
                .frame(width: Grid.unit, height: Grid.unit)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .glassSurface(Circle(), interactive: true)
        .opacity(isEnabled || isSpinning ? 1 : 0.45)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct ToggleTile: View {
    let symbol: String
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                IconCircle(symbol: symbol, isOn: isOn)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(isOn ? "Ativado" : "Desativado")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 13)
            .frame(width: Grid.wideTile, height: Grid.unit)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .glassSurface(Capsule(), interactive: true)
        .help("Iniciar ao fazer login")
        .accessibilityValue(isOn ? "Ativado" : "Desativado")
    }
}

private struct ErrorTile: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: Grid.width)
        .glassSurface(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Estilos e feedback

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct CapsuleGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .frame(height: 28)
            .glassSurface(Capsule(), interactive: true)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private enum Haptics {
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}

private struct SpinningModifier: ViewModifier {
    let isActive: Bool
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onChange(of: isActive) { active in
                if active {
                    angle = 0
                    withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                } else {
                    withAnimation(.spring(response: 0.3)) { angle = 0 }
                }
            }
    }
}

private extension View {
    func spinning(_ isActive: Bool) -> some View {
        modifier(SpinningModifier(isActive: isActive))
    }
}

// MARK: - Liquid Glass com fallback

private struct GlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: Grid.gap) { content }
        } else {
            content
        }
    }
}

private extension View {
    @ViewBuilder
    func glassSurface<S: Shape>(_ shape: S, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular.interactive(interactive), in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
    }
}

private extension ContentTransition {
    static var symbolEffectIfAvailable: ContentTransition {
        if #available(macOS 14.0, *) { return .symbolEffect(.replace) }
        return .identity
    }
}

private enum Motion {
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.85)
}
