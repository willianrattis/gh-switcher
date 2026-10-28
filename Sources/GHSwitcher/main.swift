import AppKit

/// Ciclo de vida em AppKit puro: o app não tem cenas SwiftUI, só o ícone na barra,
/// o painel e a janela de Ajustes, todos controlados pelo StatusItemController.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.requestAuthorization()
        controller = StatusItemController(store: AccountStore(), loginItem: LoginItem(), settings: AppSettings())
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
