import Foundation

struct GHAccount: Codable, Equatable, Identifiable, Sendable {
    let host: String
    let login: String
    let active: Bool
    let state: String
    let tokenSource: String?

    var id: String { "\(host)/\(login)" }
    var isValid: Bool { state == "success" }
}

/// Decodifica apenas os campos necessários; o campo `token` é ignorado.
struct GHAuthStatus: Decodable {
    let hosts: [String: [GHAccount]]

    static func parse(_ data: Data) throws -> [GHAccount] {
        let status = try JSONDecoder().decode(GHAuthStatus.self, from: data)
        return status.hosts.keys.sorted().flatMap { host in
            (status.hosts[host] ?? []).sorted { $0.login.lowercased() < $1.login.lowercased() }
        }
    }
}
