import AppKit
import SwiftUI

/// Grade da Central de Controle: 4 colunas de 62pt com espaço de 14pt.
enum Grid {
    static let unit: CGFloat = 62
    static let gap: CGFloat = 14
    static let width: CGFloat = unit * 4 + gap * 3
    static let tileHeight: CGFloat = 64
    static let iconCircle: CGFloat = 36
}

/// Blocos de Liquid Glass soltos, sem painel por trás.
struct PanelView: View {
    @ObservedObject var store: AccountStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var presentation: PanelPresentation
    let openSettings: () -> Void
    @State private var copied = false

    var body: some View {
        GlassGroup(spacing: Grid.gap) {
            VStack(spacing: 0) {
                if !settings.showLoginInMenuBar {
                    header
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }

                VStack(spacing: Grid.gap) {
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

                    if store.accounts.isEmpty && store.errorMessage == nil {
                        EmptyTile(action: openSettings)
                    }

                    if let message = store.errorMessage {
                        ErrorTile(message: message)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    }

                    controls
                }

                Button("Sair do GH Switcher") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(FooterCapsuleStyle())
                    .keyboardShortcut("q")
                    .padding(.top, 18)
            }
            .frame(width: Grid.width)
        }
        .environment(\.glassStyle, settings.glassStyle)
        .animation(Motion.snappy, value: store.accounts)
        .animation(Motion.snappy, value: store.errorMessage)
        .animation(Motion.snappy, value: settings.showLoginInMenuBar)
        .scaleEffect(presentation.isShown ? 1 : 0.94, anchor: .top)
        .opacity(presentation.isShown ? 1 : 0)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(nsImage: GitHubMark.image(size: 14))
                .renderingMode(.template)
            Text(store.activeAccount?.login ?? "Nenhuma conta ativa")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .contentTransition(.opacity)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .frame(width: Grid.width, height: 32)
        .glassSurface(Capsule())
        .help("Conta ativa")
    }

    private var controls: some View {
        HStack(spacing: Grid.gap) {
            RoundControl(symbol: "arrow.clockwise", help: "Atualizar", isSpinning: store.isRefreshing) {
                Haptics.tap()
                Task { await store.userRefresh() }
            }
            .disabled(store.isRefreshing)

            RoundControl(symbol: copied ? "checkmark" : "doc.on.doc", help: "Copiar login ativo") {
                Haptics.tap()
                store.copyActiveLogin()
                withAnimation(Motion.snappy) { copied = true }
                Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    withAnimation(Motion.snappy) { copied = false }
                }
            }
            .disabled(store.activeAccount == nil)

            RoundControl(symbol: "safari", help: "Abrir perfil no GitHub") {
                Haptics.tap()
                if let account = store.activeAccount,
                   let url = URL(string: "https://\(account.host)/\(account.login)") {
                    NSWorkspace.shared.open(url)
                }
            }
            .disabled(store.activeAccount == nil)

            RoundControl(symbol: "gearshape", help: "Ajustes…") {
                Haptics.tap()
                openSettings()
            }
            .keyboardShortcut(",")
        }
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
            .padding(.horizontal, 12)
            .padding(.bottom, -6)
    }
}

/// Círculo de ícone da Central de Controle: branco com ícone azul quando ligado.
private struct IconCircle: View {
    let symbol: String
    let isOn: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isOn ? Color.accentColor : Color.primary)
            .frame(width: Grid.iconCircle, height: Grid.iconCircle)
            .background(Circle().fill(isOn ? Color.white : Color.primary.opacity(0.14)))
            .animation(Motion.snappy, value: isOn)
    }
}

private struct AccountTile: View {
    let account: GHAccount
    let isSwitching: Bool
    let isLocked: Bool
    let action: () -> Void
    @State private var hovering = false

    private let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

    var body: some View {
        Button {
            if !account.active && account.isValid && !isLocked { action() }
        } label: {
            HStack(spacing: 10) {
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
                        .lineLimit(2)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
                if isSwitching {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .frame(width: Grid.width, height: Grid.tileHeight)
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .glassSurface(shape, interactive: !account.active)
        .overlay(shape.strokeBorder(Color.accentColor.opacity(account.active ? 0.6 : 0), lineWidth: 1))
        .brightness(hovering && !account.active ? 0.04 : 0)
        .onHover { hovering = $0 }
        .help(account.active ? "Conta ativa" : "Ativar \(account.login)")
        .accessibilityAddTraits(account.active ? .isSelected : [])
    }

    private var subtitle: String {
        if isSwitching { return "Ativando…" }
        if !account.isValid { return "Sessão inválida. Entre de novo nos Ajustes" }
        let source = account.host == "github.com" ? "GitHub" : account.host
        return account.active ? "Ativa · \(source)" : source
    }
}

private struct RoundControl: View {
    let symbol: String
    let help: String
    var isSpinning = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(.primary)
                .contentTransition(.symbolEffectIfAvailable)
                .spinning(isSpinning)
                .frame(width: Grid.unit, height: Grid.unit)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .glassSurface(Circle(), interactive: true)
        .brightness(hovering && isEnabled ? 0.04 : 0)
        .onHover { hovering = $0 }
        .opacity(isEnabled || isSpinning ? 1 : 0.4)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct EmptyTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                IconCircle(symbol: "plus", isOn: false)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Adicionar conta")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Nenhuma conta no GitHub CLI")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 14)
            .frame(width: Grid.width, height: Grid.tileHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .glassSurface(RoundedRectangle(cornerRadius: 30, style: .continuous), interactive: true)
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
        .glassSurface(RoundedRectangle(cornerRadius: 22, style: .continuous))
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

/// Rodapé discreto, como "Editar Controles".
private struct FooterCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .frame(height: 26)
            .glassSurface(Capsule(), interactive: true)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

enum Haptics {
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}

enum Motion {
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.85)
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

private extension ContentTransition {
    static var symbolEffectIfAvailable: ContentTransition {
        if #available(macOS 14.0, *) { return .symbolEffect(.replace) }
        return .identity
    }
}
