import AppKit
import Foundation

/// Código de uso único do fluxo `gh auth login --web`.
struct DeviceCode: Equatable {
    let code: String
    let url: URL

    static let defaultURL = URL(string: "https://github.com/login/device")!

    /// Extrai o código e a URL da saída do gh. Nada além disso é guardado.
    static func parse(_ text: String) -> DeviceCode? {
        guard let code = firstMatch(#"\b[A-Z0-9]{4}-[A-Z0-9]{4}\b"#, in: text) else { return nil }
        let url = firstMatch(#"https?://\S+/login/device"#, in: text).flatMap(URL.init(string:)) ?? defaultURL
        return DeviceCode(code: code, url: url)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }
}

/// Executa `gh auth login --web` e expõe só o código de uso único.
/// O token fica com o gh (Keychain); a saída nunca é registrada em log.
@MainActor
final class LoginFlow: ObservableObject {
    enum Phase: Equatable {
        case idle
        case starting
        case waiting(DeviceCode)
        case done
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle

    private var process: Process?
    private var buffer = ""
    private var cancelled = false

    var isRunning: Bool { process != nil }

    func start(host: String) async {
        guard process == nil else { return }
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty else { return }
        guard let gh = await GHCLI.locate() else {
            phase = .failed(GHError.notFound.localizedDescription)
            return
        }
        buffer = ""
        cancelled = false
        phase = .starting

        let process = GHCLI.makeProcess(gh, ["auth", "login", "--hostname", host, "--web",
                                             "--git-protocol", "https", "--skip-ssh-key"])
        let err = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = err
        err.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self?.consume(text) }
        }
        process.terminationHandler = { [weak self] finished in
            err.fileHandleForReading.readabilityHandler = nil
            let status = finished.terminationStatus
            Task { @MainActor in self?.finish(status: status) }
        }
        do {
            try process.run()
            self.process = process
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func cancel() {
        cancelled = true
        process?.terminate()
    }

    func reset() {
        if process == nil { phase = .idle }
    }

    func copyCodeAndOpenBrowser() {
        guard case .waiting(let device) = phase else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(device.code, forType: .string)
        NSWorkspace.shared.open(device.url)
    }

    private func consume(_ text: String) {
        buffer += text
        if case .starting = phase, let device = DeviceCode.parse(buffer) {
            phase = .waiting(device)
        }
    }

    private func finish(status: Int32) {
        process = nil
        defer { buffer = "" }
        if cancelled {
            phase = .idle
        } else if status == 0 {
            phase = .done
        } else {
            let line = buffer.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .last { !$0.isEmpty && DeviceCode.parse($0) == nil }
            phase = .failed(line ?? "Não foi possível entrar (código \(status))")
        }
    }
}
