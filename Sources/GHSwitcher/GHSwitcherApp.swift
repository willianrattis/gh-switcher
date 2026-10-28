import SwiftUI

@main
struct GHSwitcherApp: App {
    @StateObject private var store = AccountStore()
    @StateObject private var loginItem = LoginItem()

    init() {
        Notifier.requestAuthorization()
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store, loginItem: loginItem)
        } label: {
            Image(systemName: "person.crop.circle")
                .accessibilityLabel("GH Switcher: \(store.activeAccount?.login ?? "sem conta")")
        }
        .menuBarExtraStyle(.window)
    }
}
