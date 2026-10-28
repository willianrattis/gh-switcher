import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case accounts, general, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accounts: return "Contas"
        case .general: return "Geral"
        case .about: return "Sobre"
        }
    }

    var symbol: String {
        switch self {
        case .accounts: return "person.2.fill"
        case .general: return "switch.2"
        case .about: return "info.circle"
        }
    }
}

/// Janela de Ajustes: barra lateral só de ícones e conteúdo em seções agrupadas.
struct SettingsView: View {
    @ObservedObject var store: AccountStore
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var settings: AppSettings
    @State private var pane: SettingsPane = .accounts

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                Text(pane.title)
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                Divider()
                Group {
                    switch pane {
                    case .accounts: AccountsPane(store: store)
                    case .general: GeneralPane(loginItem: loginItem, settings: settings)
                    case .about: AboutPane()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 600, height: 620)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(spacing: 8) {
            ForEach(SettingsPane.allCases) { item in
                Button {
                    pane = item
                } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(pane == item ? Color.white : Color.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(pane == item ? Color.accentColor : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.title)
                .accessibilityLabel(item.title)
            }
            Spacer()
        }
        .padding(.top, 60)
        .frame(width: 70)
        .frame(maxHeight: .infinity)
        .background(VisualEffect(material: .sidebar).ignoresSafeArea())
    }
}

// MARK: - Contas

private struct AccountsPane: View {
    @ObservedObject var store: AccountStore
    @State private var addingAccount = false
    @State private var pendingLogout: GHAccount?

    var body: some View {
        Form {
            if store.accounts.isEmpty {
                Section {
                    Text(store.errorMessage ?? "Nenhuma conta no GitHub CLI.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(store.accountsByHost, id: \.host) { group in
                Section(group.host) {
                    ForEach(group.accounts) { account in
                        AccountRow(account: account,
                                   isBusy: store.switchingID == account.id,
                                   activate: { Task { await store.switchTo(account) } },
                                   logout: { pendingLogout = account })
                    }
                }
            }
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Adicionar conta")
                        Text("Entra pelo navegador com o GitHub CLI. O token fica no Keychain e o app nunca o lê.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Adicionar…") { addingAccount = true }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $addingAccount) {
            AddAccountSheet(store: store)
        }
        .confirmationDialog("Sair da conta \(pendingLogout?.login ?? "")?",
                            isPresented: Binding(get: { pendingLogout != nil },
                                                 set: { if !$0 { pendingLogout = nil } }),
                            presenting: pendingLogout) { account in
            Button("Sair", role: .destructive) {
                Task { await store.logout(account) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { account in
            Text("O GitHub CLI vai remover as credenciais de \(account.login) em \(account.host). Você pode entrar de novo depois.")
        }
        .task { await store.refresh() }
    }
}

private struct AccountRow: View {
    let account: GHAccount
    let isBusy: Bool
    let activate: () -> Void
    let logout: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Avatar(account: account)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(account.login).fontWeight(.medium)
                    if account.active {
                        Text("Ativa")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor))
                    }
                }
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(account.isValid ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
            }
            Spacer()
            if isBusy {
                ProgressView().controlSize(.small)
            } else {
                if !account.active {
                    Button("Ativar", action: activate)
                        .disabled(!account.isValid)
                }
                Button("Sair…", role: .destructive, action: logout)
            }
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        guard account.isValid else { return "Sessão inválida. Saia e adicione a conta de novo." }
        let source = account.tokenSource == "keyring" ? "Keychain" : (account.tokenSource ?? "desconhecido")
        return "Credencial: \(source)"
    }
}

private struct Avatar: View {
    let account: GHAccount

    var body: some View {
        Group {
            if account.host == "github.com",
               let url = URL(string: "https://github.com/\(account.login).png?size=64") {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.1)))
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.opacity(0.08))
    }
}

private struct AddAccountSheet: View {
    @ObservedObject var store: AccountStore
    @StateObject private var flow = LoginFlow()
    @State private var host = "github.com"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(nsImage: GitHubMark.image(size: 28))
                    .renderingMode(.template)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adicionar conta").font(.headline)
                    Text("Login pelo navegador com o GitHub CLI")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            content

            HStack {
                Spacer()
                switch flow.phase {
                case .idle, .failed:
                    Button("Cancelar") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Continuar") { Task { await flow.start(host: host) } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
                case .starting, .waiting:
                    Button("Cancelar") { flow.cancel() }
                        .keyboardShortcut(.cancelAction)
                case .done:
                    Button("Concluir") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 420)
        .onChange(of: flow.phase) { phase in
            if phase == .done {
                Task { await store.refresh() }
            }
        }
        .onDisappear { flow.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        switch flow.phase {
        case .idle, .failed:
            VStack(alignment: .leading, spacing: 6) {
                Text("Servidor").font(.system(size: 12, weight: .medium))
                TextField("github.com", text: $host)
                    .textFieldStyle(.roundedBorder)
                Text("Use github.com ou o endereço do seu GitHub Enterprise.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if case .failed(let message) = flow.phase {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        case .starting:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Iniciando o GitHub CLI…").foregroundStyle(.secondary)
            }
        case .waiting(let device):
            VStack(alignment: .leading, spacing: 10) {
                Text("Copie o código e autorize no navegador:")
                Text(device.code)
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
                Button {
                    flow.copyCodeAndOpenBrowser()
                } label: {
                    Label("Copiar código e abrir o GitHub", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Aguardando a autorização…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        case .done:
            Label("Conta adicionada e ativada.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}

// MARK: - Geral

private struct GeneralPane: View {
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var settings: AppSettings
    @State private var detectedPath: String?

    var body: some View {
        Form {
            Section("Geral") {
                Toggle(isOn: Binding(get: { loginItem.isEnabled }, set: { _ in loginItem.toggle() })) {
                    SettingLabel("Abrir no login",
                                 detail: loginItem.errorMessage ?? "Inicia o GH Switcher quando você entra no Mac.")
                }
                Toggle(isOn: $settings.notificationsEnabled) {
                    SettingLabel("Notificar ao trocar de conta")
                }
            }
            Section("Barra de menus") {
                Toggle(isOn: $settings.showLoginInMenuBar) {
                    SettingLabel("Mostrar login ao lado do ícone")
                }
                Picker(selection: $settings.glassStyle) {
                    ForEach(GlassStyle.allCases) { Text($0.title).tag($0) }
                } label: {
                    SettingLabel("Vidro do painel",
                                 detail: "Transparente segue a Central de Controle. Padrão é mais opaco.")
                }
            }
            Section("GitHub CLI") {
                LabeledContent {
                    HStack {
                        TextField("", text: $settings.ghPath, prompt: Text(detectedPath ?? "Automático"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                        Button("Detectar") {
                            settings.ghPath = ""
                            Task { detectedPath = await GHCLI.locate() }
                        }
                    }
                } label: {
                    SettingLabel("Caminho do gh", detail: "Deixe vazio para detectar automaticamente.")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItem.refresh() }
        .task { detectedPath = await GHCLI.locate() }
    }
}

private struct SettingLabel: View {
    let title: String
    let detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Sobre

private struct AboutPane: View {
    @State private var ghVersion = "…"

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: GitHubMark.image(size: 44))
                        .renderingMode(.template)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GH Switcher").font(.system(size: 15, weight: .semibold))
                        Text("Versão \(appVersion)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Ambiente") {
                LabeledContent("GitHub CLI", value: ghVersion)
            }
            Section("Segurança") {
                Text("O app nunca lê, grava ou exibe tokens. As credenciais ficam com o GitHub CLI, no Keychain do macOS.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { ghVersion = await GHCLI.version() ?? "não encontrado" }
    }
}

// MARK: - AppKit

private struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var keyMonitor: Any?

    init(store: AccountStore, loginItem: LoginItem, settings: AppSettings) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Ajustes do GH Switcher"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: SettingsView(store: store, loginItem: loginItem, settings: settings)
        )
        window.center()
        window.setFrameAutosaveName("GHSwitcherSettings")
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    /// App sem menu principal: trata ⌘W manualmente.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let window = self?.window, window.isKeyWindow,
                  event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers == "w" else { return event }
            window.performClose(nil)
            return nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
