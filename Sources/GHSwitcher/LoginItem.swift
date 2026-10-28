import ServiceManagement

@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var errorMessage: String?

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Iniciar ao fazer login: \(error.localizedDescription)"
        }
        refresh()
    }
}
