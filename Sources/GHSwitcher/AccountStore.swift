import AppKit
import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [GHAccount] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isBusy = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var switchingID: String?
    /// O gh não foi encontrado na última atualização.
    @Published private(set) var ghMissing = false
    /// Já houve pelo menos uma atualização (evita mostrar boas-vindas antes da hora).
    @Published private(set) var hasLoaded = false
    @Published private(set) var isInstallingGH = false
    @Published private(set) var installError: String?

    private var timer: Timer?

    var activeAccount: GHAccount? { accounts.first { $0.active } }

    var accountsByHost: [(host: String, accounts: [GHAccount])] {
        Dictionary(grouping: accounts, by: \.host)
            .map { (host: $0.key, accounts: $0.value) }
            .sorted { $0.host < $1.host }
    }

    /// Precisa de configuração: sem gh ou sem nenhuma conta.
    var needsOnboarding: Bool { hasLoaded && (ghMissing || accounts.isEmpty) }

    init() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    /// Atualização pedida pelo usuário: mantém o indicador visível por um tempo mínimo.
    func userRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let start = Date()
        await refresh()
        let remaining = 0.6 - Date().timeIntervalSince(start)
        if remaining > 0 { try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
        isRefreshing = false
    }

    func refresh() async {
        defer { hasLoaded = true }
        do {
            accounts = try await GHCLI.listAccounts()
            ghMissing = false
            let invalid = accounts.filter { !$0.isValid }.map(\.login)
            errorMessage = invalid.isEmpty
                ? nil
                : String(localized: "Invalid session: \(invalid.joined(separator: ", "))")
        } catch GHError.notFound {
            accounts = []
            ghMissing = true
            errorMessage = nil
        } catch {
            accounts = []
            ghMissing = false
            errorMessage = error.localizedDescription
        }
    }

    func installGH() async {
        guard !isInstallingGH else { return }
        isInstallingGH = true
        installError = nil
        defer { isInstallingGH = false }
        do {
            try await GHCLI.installWithBrew()
            await refresh()
        } catch {
            installError = error.localizedDescription
        }
    }

    func switchTo(_ account: GHAccount) async {
        guard !account.active, !isBusy else { return }
        isBusy = true
        switchingID = account.id
        defer {
            isBusy = false
            switchingID = nil
        }
        do {
            try await GHCLI.switchAccount(host: account.host, login: account.login)
            await refresh()
            let login = activeAccount?.login ?? account.login
            Notifier.send(String(localized: "Active GitHub account: \(login)"))
        } catch {
            errorMessage = error.localizedDescription
            Notifier.send(String(localized: "Couldn't switch account: \(error.localizedDescription)"))
        }
    }

    func logout(_ account: GHAccount) async {
        guard !isBusy else { return }
        isBusy = true
        switchingID = account.id
        defer {
            isBusy = false
            switchingID = nil
        }
        do {
            try await GHCLI.logout(host: account.host, login: account.login)
            await refresh()
            Notifier.send(String(localized: "Signed out of \(account.login)"))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyActiveLogin() {
        guard let login = activeAccount?.login else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(login, forType: .string)
    }
}
