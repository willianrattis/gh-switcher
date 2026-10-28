#if DEBUG
import Foundation

/// Dados fictícios para prints e GIFs (GHS_DEMO=1). Só existe em builds de desenvolvimento.
enum Demo {
    static let isEnabled = ProcessInfo.processInfo.environment["GHS_DEMO"] == "1"
    /// Tour para vídeo: painel, trocas de conta e navegação pelos Ajustes.
    static let isTour = isEnabled && ProcessInfo.processInfo.environment["GHS_DEMO_TOUR"] == "1"

    static var accounts: [GHAccount] = [
        GHAccount(host: "github.com", login: "jane-doe", active: true, state: "success", tokenSource: "keyring"),
        GHAccount(host: "github.com", login: "jane-doe-work", active: false, state: "success", tokenSource: "keyring"),
    ]

    static func activate(_ account: GHAccount) {
        accounts = accounts.map {
            GHAccount(host: $0.host, login: $0.login, active: $0.id == account.id,
                      state: $0.state, tokenSource: $0.tokenSource)
        }
    }
}
#endif
