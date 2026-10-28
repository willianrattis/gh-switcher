import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case accounts, general, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accounts: return String(localized: "Accounts")
        case .general: return String(localized: "General")
        case .about: return String(localized: "About")
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
            if store.ghMissing {
                InstallGHSection(store: store)
            } else if store.accounts.isEmpty {
                Section {
                    Text(store.errorMessage ?? String(localized: "No accounts in GitHub CLI yet."))
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
                        Text("Add account")
                        Text("Sign in through your browser with GitHub CLI. The token stays in the Keychain; this app never reads it.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Add…") { addingAccount = true }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $addingAccount) {
            AddAccountSheet(store: store)
        }
        .confirmationDialog(Text("Sign out of \(pendingLogout?.login ?? "")?"),
                            isPresented: Binding(get: { pendingLogout != nil },
                                                 set: { if !$0 { pendingLogout = nil } }),
                            presenting: pendingLogout) { account in
            Button("Sign Out", role: .destructive) {
                Task { await store.logout(account) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { account in
            Text("GitHub CLI will remove the credentials for \(account.login) on \(account.host). You can sign in again later.")
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
                        Text("Active")
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
                    Button("Switch", action: activate)
                        .disabled(!account.isValid)
                }
                Button("Sign Out…", role: .destructive, action: logout)
            }
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        guard account.isValid else { return String(localized: "Session expired. Sign out and add the account again.") }
        let source = account.tokenSource == "keyring" ? "Keychain" : (account.tokenSource ?? String(localized: "unknown"))
        return String(localized: "Credentials: \(source)")
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
                    Text("Add account").font(.headline)
                    Text("Sign in through your browser with GitHub CLI")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            content

            HStack {
                Spacer()
                switch flow.phase {
                case .idle, .failed:
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Continue") { Task { await flow.start(host: host) } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
                case .starting, .waiting:
                    Button("Cancel") { flow.cancel() }
                        .keyboardShortcut(.cancelAction)
                case .done:
                    Button("Done") { dismiss() }
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
                Text("Server").font(.system(size: 12, weight: .medium))
                TextField("github.com", text: $host)
                    .textFieldStyle(.roundedBorder)
                Text("Use github.com or your GitHub Enterprise address.")
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
                Text("Starting GitHub CLI…").foregroundStyle(.secondary)
            }
        case .waiting(let device):
            VStack(alignment: .leading, spacing: 10) {
                Text("Copy the code and authorize in your browser:")
                Text(device.code)
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
                Button {
                    flow.copyCodeAndOpenBrowser()
                } label: {
                    Label("Copy Code and Open GitHub", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for authorization…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        case .done:
            Label("Account added and activated.", systemImage: "checkmark.circle.fill")
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
            Section("General") {
                Toggle(isOn: Binding(get: { loginItem.isEnabled }, set: { _ in loginItem.toggle() })) {
                    SettingLabel("Open at Login",
                                 detail: loginItem.errorMessage ?? String(localized: "Start GH Switcher when you log in to your Mac."))
                }
                Toggle(isOn: $settings.notificationsEnabled) {
                    SettingLabel("Notify when switching accounts")
                }
            }
            Section("Menu Bar") {
                Toggle(isOn: $settings.showLoginInMenuBar) {
                    SettingLabel("Show login next to the icon")
                }
                Picker(selection: $settings.glassStyle) {
                    ForEach(GlassStyle.allCases) { Text($0.title).tag($0) }
                } label: {
                    SettingLabel("Panel glass",
                                 detail: String(localized: "Clear matches Control Center. Regular is more opaque."))
                }
            }
            Section("GitHub CLI") {
                LabeledContent {
                    HStack {
                        TextField("", text: $settings.ghPath, prompt: Text(detectedPath ?? String(localized: "Automatic")))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                        Button("Detect") {
                            settings.ghPath = ""
                            Task { detectedPath = await GHCLI.locate() }
                        }
                    }
                } label: {
                    SettingLabel("gh path", detail: String(localized: "Leave empty to detect automatically."))
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItem.refresh() }
        .task { detectedPath = await GHCLI.locate() }
    }
}

private struct SettingLabel: View {
    let title: LocalizedStringKey
    let detail: String?

    init(_ title: LocalizedStringKey, detail: String? = nil) {
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
                        Text("Version \(appVersion)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Environment") {
                LabeledContent("GitHub CLI", value: ghVersion)
            }
            Section("Links") {
                Link(destination: Links.repository) {
                    Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: Links.sponsor) {
                    Label("Sponsor GH Switcher", systemImage: "heart")
                }
                Link(destination: Links.issues) {
                    Label("Report an issue", systemImage: "exclamationmark.bubble")
                }
            }
            Section("Security") {
                Text("This app never reads, stores or displays tokens. Credentials stay with GitHub CLI in the macOS Keychain.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Section {
                Text("Licensed under FSL-1.1-MIT. Not affiliated with GitHub, Inc.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { ghVersion = await GHCLI.version() ?? String(localized: "not found") }
    }
}

enum Links {
    static let repository = URL(string: "https://github.com/willianrattis/gh-switcher")!
    static let issues = URL(string: "https://github.com/willianrattis/gh-switcher/issues")!
    static let sponsor = URL(string: "https://github.com/sponsors/willianrattis")!
    static let ghCLI = URL(string: "https://cli.github.com")!
}

// MARK: - Boas-vindas

/// Mostrada quando o GitHub CLI não está instalado.
private struct InstallGHSection: View {
    @ObservedObject var store: AccountStore
    private let hasBrew = GHCLI.locateBrew() != nil

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(nsImage: GitHubMark.image(size: 32))
                        .renderingMode(.template)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Welcome to GH Switcher").font(.system(size: 13, weight: .semibold))
                        Text("GH Switcher uses the GitHub CLI (gh) to switch accounts. Install it to get started.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    if hasBrew {
                        Button {
                            Task { await store.installGH() }
                        } label: {
                            if store.isInstallingGH {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("Installing…")
                                }
                            } else {
                                Text("Install with Homebrew")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isInstallingGH)
                    } else {
                        Link("Download GitHub CLI", destination: Links.ghCLI)
                            .buttonStyle(.borderedProminent)
                    }
                    Button("Check Again") { Task { await store.userRefresh() } }
                        .disabled(store.isInstallingGH)
                    Spacer()
                }
                if let error = store.installError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
        }
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
        window.title = String(localized: "GH Switcher Settings")
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
