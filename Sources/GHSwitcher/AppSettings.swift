import Foundation

enum GlassStyle: String, CaseIterable, Identifiable {
    case clear
    case regular

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clear: return "Transparente"
        case .regular: return "Padrão"
        }
    }
}

/// Preferências do app (UserDefaults).
@MainActor
final class AppSettings: ObservableObject {
    static let notificationsKey = "notificationsEnabled"

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Self.notificationsKey) }
    }
    @Published var showLoginInMenuBar: Bool {
        didSet { defaults.set(showLoginInMenuBar, forKey: "showLoginInMenuBar") }
    }
    @Published var glassStyle: GlassStyle {
        didSet { defaults.set(glassStyle.rawValue, forKey: "glassStyle") }
    }
    @Published var ghPath: String {
        didSet {
            let trimmed = ghPath.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                defaults.removeObject(forKey: GHCLI.pathKey)
            } else {
                defaults.set(trimmed, forKey: GHCLI.pathKey)
            }
        }
    }

    private let defaults = UserDefaults.standard

    init() {
        notificationsEnabled = defaults.object(forKey: Self.notificationsKey) as? Bool ?? true
        showLoginInMenuBar = defaults.bool(forKey: "showLoginInMenuBar")
        glassStyle = GlassStyle(rawValue: defaults.string(forKey: "glassStyle") ?? "") ?? .clear
        ghPath = defaults.string(forKey: GHCLI.pathKey) ?? ""
    }
}
