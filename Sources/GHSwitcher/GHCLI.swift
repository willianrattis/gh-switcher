import Foundation

enum GHError: LocalizedError {
    case notFound
    case failed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .notFound: return String(localized: "GitHub CLI (gh) not found")
        case .failed(let message): return message
        case .invalidOutput: return String(localized: "Unexpected output from gh")
        }
    }
}

struct ProcessResult: Sendable {
    let status: Int32
    let stdout: Data
    let stderr: Data
}

enum GHCLI {
    static let pathKey = "ghPath"

    static func locate() async -> String? {
        let fm = FileManager.default
        if let custom = UserDefaults.standard.string(forKey: pathKey), fm.isExecutableFile(atPath: custom) {
            return custom
        }
        for path in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"] where fm.isExecutableFile(atPath: path) {
            return path
        }
        if let result = try? await run("/bin/zsh", ["-lc", "command -v gh"]), result.status == 0 {
            let path = String(decoding: result.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if fm.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    /// Homebrew, usado para instalar o gh quando ele não existe.
    static func locateBrew() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    static func installWithBrew() async throws {
        guard let brew = locateBrew() else { throw GHError.failed(String(localized: "Homebrew not found")) }
        let result = try await run(brew, ["install", "gh"])
        if result.status != 0 { throw GHError.failed(message(from: result)) }
    }

    static func listAccounts() async throws -> [GHAccount] {
        guard let gh = await locate() else { throw GHError.notFound }
        let result = try await run(gh, ["auth", "status", "--json", "hosts"])
        // Com conta inválida o gh pode sair com código 1 e ainda imprimir JSON.
        if let accounts = try? GHAuthStatus.parse(result.stdout) { return accounts }
        if result.status != 0 { throw GHError.failed(message(from: result)) }
        throw GHError.invalidOutput
    }

    static func switchAccount(host: String, login: String) async throws {
        guard let gh = await locate() else { throw GHError.notFound }
        let result = try await run(gh, ["auth", "switch", "--hostname", host, "--user", login])
        if result.status != 0 { throw GHError.failed(message(from: result)) }
    }

    static func logout(host: String, login: String) async throws {
        guard let gh = await locate() else { throw GHError.notFound }
        let result = try await run(gh, ["auth", "logout", "--hostname", host, "--user", login])
        if result.status != 0 { throw GHError.failed(message(from: result)) }
    }

    static func version() async -> String? {
        guard let gh = await locate(), let result = try? await run(gh, ["--version"]), result.status == 0 else {
            return nil
        }
        return String(decoding: result.stdout, as: UTF8.self)
            .split(separator: "\n").first
            .map(String.init)
    }

    private static func message(from result: ProcessResult) -> String {
        let text = String(decoding: result.stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = text.split(separator: "\n").first.map(String.init) ?? ""
        return firstLine.isEmpty ? String(localized: "gh command failed (exit code \(Int(result.status)))") : firstLine
    }

    static func makeProcess(_ executable: String, _ arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        let path = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + path
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        env["GH_PROMPT_DISABLED"] = "1"
        env["NO_COLOR"] = "1"
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        return process
    }

    static func run(_ executable: String, _ arguments: [String]) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = makeProcess(executable, arguments)
                let out = Pipe()
                let err = Pipe()
                process.standardOutput = out
                process.standardError = err
                do {
                    try process.run()
                    // Lê stderr em paralelo para o processo não travar com o buffer cheio.
                    var errData = Data()
                    let group = DispatchGroup()
                    group.enter()
                    DispatchQueue.global().async {
                        errData = err.fileHandleForReading.readDataToEndOfFile()
                        group.leave()
                    }
                    let outData = out.fileHandleForReading.readDataToEndOfFile()
                    group.wait()
                    process.waitUntilExit()
                    continuation.resume(returning: ProcessResult(status: process.terminationStatus, stdout: outData, stderr: errData))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
