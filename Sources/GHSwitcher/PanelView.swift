import AppKit
import SwiftUI

/// Painel no estilo da Central de Controle do macOS (Liquid Glass).
struct PanelView: View {
    @ObservedObject var store: AccountStore
    @ObservedObject var loginItem: LoginItem
    @State private var copied = false

    var body: some View {
        GlassGroup {
            VStack(spacing: 10) {
                header
                    .padding(.bottom, 2)

                ForEach(store.accountsByHost, id: \.host) { group in
                    if store.accountsByHost.count > 1 {
                        SectionTitle(group.host)
                    }
                    ForEach(group.accounts) { account in
                        AccountTile(account: account, busy: store.isBusy) {
                            Task { await store.switchTo(account) }
                        }
                    }
                }

                if let message = store.errorMessage ?? loginItem.errorMessage {
                    ErrorTile(message: message)
                }

                HStack(spacing: 10) {
                    RoundControl(symbol: "arrow.clockwise", help: "Atualizar") {
                        Task { await store.refresh() }
                    }
                    RoundControl(symbol: copied ? "checkmark" : "doc.on.doc",
                                 help: "Copiar login ativo") {
                        store.copyActiveLogin()
                        copied = true
                        Task {
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            copied = false
                        }
                    }
                    .disabled(store.activeAccount == nil)
                    ToggleTile(symbol: "power",
                               title: "Abrir no login",
                               isOn: loginItem.isEnabled) {
                        loginItem.toggle()
                    }
                }

                Button("Sair do GH Switcher") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(CapsuleGlassButtonStyle())
                    .keyboardShortcut("q")
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(width: 304)
        .onAppear {
            loginItem.refresh()
            Task { await store.refresh() }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.crop.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.accentColor)
                .font(.system(size: 14))
            Text(store.activeAccount.map { "Conta ativa: \($0.login)" } ?? "Nenhuma conta ativa")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
            .padding(.horizontal, 8)
    }
}

/// Círculo de ícone da Central de Controle: azul preenchido quando ligado.
private struct IconCircle: View {
    let symbol: String
    let isOn: Bool
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .frame(width: size, height: size)
            .background(Circle().fill(isOn ? Color.accentColor : Color.primary.opacity(0.1)))
    }
}

private struct AccountTile: View {
    let account: GHAccount
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if !account.active && account.isValid && !busy { action() }
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
                }
                Spacer(minLength: 0)
                if account.active {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                } else if busy {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 52)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassSurface(RoundedRectangle(cornerRadius: 26, style: .continuous),
                      interactive: !account.active)
        .help(account.active ? "Conta ativa" : "Ativar \(account.login)")
        .accessibilityAddTraits(account.active ? .isSelected : [])
    }

    private var subtitle: String {
        if !account.isValid { return "Precisa de login no terminal" }
        let source = account.host == "github.com" ? "GitHub" : account.host
        return account.active ? "Ativa · \(source)" : source
    }
}

private struct RoundControl: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
                .contentTransition(.symbolEffectIfAvailable)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassSurface(Circle(), interactive: true)
        .opacity(isEnabled ? 1 : 0.45)
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
            HStack(spacing: 8) {
                IconCircle(symbol: symbol, isOn: isOn, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(isOn ? "Ativado" : "Desativado")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
        .padding(12)
        .glassSurface(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct CapsuleGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .glassSurface(Capsule(), interactive: true)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Liquid Glass com fallback

private struct GlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 10) { content }
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
        }
    }
}

private extension ContentTransition {
    static var symbolEffectIfAvailable: ContentTransition {
        if #available(macOS 14.0, *) { return .symbolEffect(.replace) }
        return .identity
    }
}
