import AppKit
import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [GHAccount] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isBusy = false

    private var timer: Timer?

    var activeAccount: GHAccount? { accounts.first { $0.active } }

    var accountsByHost: [(host: String, accounts: [GHAccount])] {
        Dictionary(grouping: accounts, by: \.host)
            .map { (host: $0.key, accounts: $0.value) }
            .sorted { $0.host < $1.host }
    }

    init() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    @Published private(set) var isRefreshing = false
    @Published private(set) var switchingID: String?

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
        do {
            accounts = try await GHCLI.listAccounts()
            let invalid = accounts.filter { !$0.isValid }.map(\.login)
            errorMessage = invalid.isEmpty ? nil : "Conta inválida: " + invalid.joined(separator: ", ")
        } catch {
            accounts = []
            errorMessage = error.localizedDescription
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
            Notifier.send("Conta GitHub ativa: \(activeAccount?.login ?? account.login)")
        } catch {
            errorMessage = error.localizedDescription
            Notifier.send("Erro ao trocar conta: \(error.localizedDescription)")
        }
    }

    func copyActiveLogin() {
        guard let login = activeAccount?.login else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(login, forType: .string)
    }
}
