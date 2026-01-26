#if os(macOS)
import Foundation

@MainActor
public final class PomodoroBlocker: ObservableObject, PomodoroBlocking {
    public static let shared = PomodoroBlocker()

    private let defaults = UserDefaults.standard
    private let hostsPath = "/etc/hosts"
    private let blockStartMarker = "# Pomafocus Block Start"
    private let blockEndMarker = "# Pomafocus Block End"
    private let blockAddress = "127.0.0.1"
    private let workQueue = DispatchQueue(label: "com.staskus.pomafocus.blocking", qos: .utility)

    private var blockedDomains: [String] = []

    private enum Keys {
        static let blockedDomains = "pomodoro.blockedDomains"
    }

    public private(set) var blockedDomainsText: String

    private init() {
        blockedDomainsText = defaults.string(forKey: Keys.blockedDomains) ?? ""
        blockedDomains = parseDomains(from: blockedDomainsText)
    }

    public func updateBlockedDomainsText(_ text: String) {
        blockedDomainsText = text
        defaults.set(text, forKey: Keys.blockedDomains)
        blockedDomains = parseDomains(from: text)
    }

    public func beginBlocking() {
        applyBlocking(enabled: true)
    }

    public func endBlocking() {
        applyBlocking(enabled: false)
    }

    public var hasSelection: Bool { !blockedDomains.isEmpty }

    public var selectionSummary: String {
        if blockedDomains.isEmpty {
            return "No websites blocked"
        }
        return "Blocking \(blockedDomains.count) website\(blockedDomains.count == 1 ? "" : "s")"
    }

    private func applyBlocking(enabled: Bool) {
        let domains = blockedDomains
        let hostsPath = hostsPath
        let blockStartMarker = blockStartMarker
        let blockEndMarker = blockEndMarker
        let blockAddress = blockAddress
        workQueue.async {
            guard let originalHosts = try? String(contentsOfFile: hostsPath, encoding: .utf8) else { return }
            let sanitizedHosts = Self.removeBlockSection(from: originalHosts, startMarker: blockStartMarker, endMarker: blockEndMarker)
            var updatedHosts = sanitizedHosts

            if enabled, !domains.isEmpty {
                if !updatedHosts.hasSuffix("\n"), !updatedHosts.isEmpty {
                    updatedHosts.append("\n")
                }
                updatedHosts.append(blockStartMarker)
                updatedHosts.append("\n")
                updatedHosts.append(domains.map { "\(blockAddress) \($0)" }.joined(separator: "\n"))
                updatedHosts.append("\n")
                updatedHosts.append(blockEndMarker)
                updatedHosts.append("\n")
            }

            Self.writeHostsFile(updatedHosts, hostsPath: hostsPath)
        }
    }

    nonisolated private static func removeBlockSection(from hosts: String, startMarker: String, endMarker: String) -> String {
        var output: [String] = []
        var skipping = false
        for line in hosts.split(whereSeparator: \.isNewline) {
            if line == startMarker {
                skipping = true
                continue
            }
            if line == endMarker {
                skipping = false
                continue
            }
            if !skipping {
                output.append(String(line))
            }
        }
        return output.joined(separator: "\n") + "\n"
    }

    nonisolated private static func writeHostsFile(_ contents: String, hostsPath: String) {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pomafocus-hosts-\(UUID().uuidString)")
        do {
            try contents.write(to: tempURL, atomically: true, encoding: .utf8)
            let installCommand = "install -m 644 \(shellEscape(tempURL.path)) \(shellEscape(hostsPath))"
            let flushCommand = "dscacheutil -flushcache && killall -HUP mDNSResponder"
            let command = "\(installCommand) && \(flushCommand)"
            guard runAppleScriptShell(command) else {
                NSLog("Pomafocus: failed to update /etc/hosts")
                return
            }
        } catch {
            return
        }
        try? FileManager.default.removeItem(at: tempURL)
    }

    nonisolated private static func runAppleScriptShell(_ command: String) -> Bool {
        let escapedCommand = appleScriptEscape(command)
        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func parseDomains(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ", \t\r\n")
        var seen = Set<String>()
        var results: [String] = []

        for raw in text.components(separatedBy: separators) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            var token = trimmed.lowercased()
            if token.hasPrefix("http://") {
                token.removeFirst("http://".count)
            } else if token.hasPrefix("https://") {
                token.removeFirst("https://".count)
            }
            if let slashIndex = token.firstIndex(of: "/") {
                token = String(token[..<slashIndex])
            }
            if let colonIndex = token.firstIndex(of: ":") {
                token = String(token[..<colonIndex])
            }
            guard !token.isEmpty else { continue }

            if seen.insert(token).inserted {
                results.append(token)
            }

            let parts = token.split(separator: ".")
            if parts.count == 2 && !token.hasPrefix("www.") {
                let www = "www.\(token)"
                if seen.insert(www).inserted {
                    results.append(www)
                }
            }
        }
        return results
    }

    nonisolated private static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    nonisolated private static func appleScriptEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
#endif
