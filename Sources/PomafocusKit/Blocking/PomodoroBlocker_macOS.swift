#if os(macOS)
import Foundation
import Combine

@MainActor
public final class PomodoroBlocker: ObservableObject, PomodoroBlocking {
    public static let shared = PomodoroBlocker()

    private let defaults = UserDefaults.standard
    private let hostsPath = "/etc/hosts"
    private let blockStartMarker = "# Pomafocus Block Start"
    private let blockEndMarker = "# Pomafocus Block End"
    private let blockAddress = "127.0.0.1"

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
        guard let originalHosts = try? String(contentsOfFile: hostsPath, encoding: .utf8) else { return }
        let sanitizedHosts = removeBlockSection(from: originalHosts)
        var updatedHosts = sanitizedHosts

        if enabled, !blockedDomains.isEmpty {
            if !updatedHosts.hasSuffix("\n"), !updatedHosts.isEmpty {
                updatedHosts.append("\n")
            }
            updatedHosts.append(blockStartMarker)
            updatedHosts.append("\n")
            updatedHosts.append(blockedDomains.map { "\(blockAddress) \($0)" }.joined(separator: "\n"))
            updatedHosts.append("\n")
            updatedHosts.append(blockEndMarker)
            updatedHosts.append("\n")
        }

        writeHostsFile(updatedHosts)
    }

    private func removeBlockSection(from hosts: String) -> String {
        var output: [String] = []
        var skipping = false
        for line in hosts.split(whereSeparator: \.isNewline) {
            if line == blockStartMarker {
                skipping = true
                continue
            }
            if line == blockEndMarker {
                skipping = false
                continue
            }
            if !skipping {
                output.append(String(line))
            }
        }
        return output.joined(separator: "\n") + "\n"
    }

    private func writeHostsFile(_ contents: String) {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pomafocus-hosts-\(UUID().uuidString)")
        do {
            try contents.write(to: tempURL, atomically: true, encoding: .utf8)
            let installCommand = "install -m 644 \(shellEscape(tempURL.path)) \(shellEscape(hostsPath))"
            let flushCommand = "dscacheutil -flushcache && killall -HUP mDNSResponder"
            let command = "\(installCommand) && \(flushCommand)"
            runAppleScriptShell(command)
        } catch {
            return
        }
        try? FileManager.default.removeItem(at: tempURL)
    }

    private func runAppleScriptShell(_ command: String) {
        let escapedCommand = appleScriptEscape(command)
        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        do {
            try process.run()
        } catch {
            return
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

    private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
#endif
