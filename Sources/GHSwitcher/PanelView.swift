import AppKit
import SwiftUI

/// Painel no estilo da Central de Controle do macOS.
struct PanelView: View {
    @ObservedObject var store: AccountStore
    @ObservedObject var loginItem: LoginItem

    var body: some View {
        VStack(spacing: 12) {
            header

            ForEach(store.accountsByHost, id: \.host) { group in
                if store.accountsByHost.count > 1 {
                    Text(group.host)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
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

            HStack(spacing: 12) {
                CircleButton(symbol: "arrow.clockwise", label: "Atualizar") {
                    Task { await store.refresh() }
                }
                CircleButton(symbol: "doc.on.doc", label: "Copiar login ativo") {
                    store.copyActiveLogin()
                }
                .disabled(store.activeAccount == nil)
                CircleButton(symbol: "power", label: "Iniciar ao fazer login",
                             highlighted: loginItem.isEnabled) {
                    loginItem.toggle()
                }
            }

            Button("Sair") { NSApplication.shared.terminate(nil) }
                .buttonStyle(PillButtonStyle())
                .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 300)
        .onAppear {
            loginItem.refresh()
            Task { await store.refresh() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white, .purple)
            Text("Conta ativa: \(store.activeAccount?.login ?? "nenhuma")")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
    }
}

private struct TileBackground: ViewModifier {
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(highlighted ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(highlighted ? Color.accentColor.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct AccountTile: View {
    let account: GHAccount
    let busy: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(account.active ? Color.accentColor : Color.white.opacity(0.14))
                    Image(systemName: account.active ? "checkmark" : "person.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(account.login)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(account.active ? Color.accentColor : .secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(TileBackground(highlighted: account.active))
        .brightness(hovering && !account.active ? 0.05 : 0)
        .onHover { hovering = $0 }
        .disabled(account.active || busy || !account.isValid)
        .opacity(account.isValid ? 1 : 0.6)
    }

    private var subtitle: String {
        if !account.isValid { return "Inválida" }
        return account.active ? "Ativa" : "Clique para ativar"
    }
}

private struct ErrorTile: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .modifier(TileBackground())
    }
}

private struct CircleButton: View {
    let symbol: String
    let label: String
    var highlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(highlighted ? Color.accentColor : Color.white.opacity(0.14))
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                Text(label)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(TileBackground())
        .help(label)
    }
}

private struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(configuration.isPressed ? 0.2 : 0.1)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
    }
}
