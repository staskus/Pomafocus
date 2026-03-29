#if os(macOS)
import AppKit
import Foundation

@MainActor
public final class PomodoroBlocker: ObservableObject, PomodoroBlocking {
    public static let shared = PomodoroBlocker()

    @Published public var blockedDomains: [String] {
        didSet { persistDomains() }
    }

    @Published public private(set) var isDaemonInstalled: Bool

    private let defaults: UserDefaults
    private let domainsKey = "pomafocus.mac.blockedWebsites"
    private var isBlocking = false
    private let hostsModifier: HostsFileModifier

    nonisolated static let markerStart = "# POMAFOCUS BLOCK START"
    nonisolated static let markerEnd = "# POMAFOCUS BLOCK END"
    nonisolated static let controlFilePath = "/tmp/pomafocus-blocked-domains"
    nonisolated static let helperPath = "/usr/local/bin/pomafocus-hosts-helper"
    nonisolated static let daemonLabel = "com.staskus.pomafocus.hosts"
    nonisolated static let daemonPlistPath = "/Library/LaunchDaemons/com.staskus.pomafocus.hosts.plist"

    init(
        defaults: UserDefaults = .standard,
        hostsModifier: HostsFileModifier = DaemonHostsModifier()
    ) {
        self.defaults = defaults
        self.hostsModifier = hostsModifier
        self.blockedDomains = defaults.stringArray(forKey: domainsKey) ?? []
        self.isDaemonInstalled = FileManager.default.fileExists(atPath: PomodoroBlocker.helperPath)
    }

    // MARK: - Daemon setup (one-time admin prompt)

    @discardableResult
    public func installDaemon() -> Bool {
        let helperScript = Self.generateHelperScript()
        let plistContent = Self.generateDaemonPlist()

        // Write files to temp first, then move with admin privileges
        let tmpHelper = NSTemporaryDirectory() + "pomafocus-hosts-helper"
        let tmpPlist = NSTemporaryDirectory() + "pomafocus-hosts-daemon.plist"
        do {
            try helperScript.write(toFile: tmpHelper, atomically: true, encoding: .utf8)
            try plistContent.write(toFile: tmpPlist, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Pomafocus: failed to write temp files: %@", error.localizedDescription)
            return false
        }

        let shellCommand = [
            "cp '\(tmpHelper)' '\(Self.helperPath)'",
            "chmod 755 '\(Self.helperPath)'",
            "cp '\(tmpPlist)' '\(Self.daemonPlistPath)'",
            "launchctl bootout system/\(Self.daemonLabel) 2>/dev/null; true",
            "launchctl bootstrap system '\(Self.daemonPlistPath)'"
        ].joined(separator: " && ")

        let success = runAppleScriptWithAdmin(shellCommand)
        try? FileManager.default.removeItem(atPath: tmpHelper)
        try? FileManager.default.removeItem(atPath: tmpPlist)

        if success {
            isDaemonInstalled = true
        }
        return success
    }

    @discardableResult
    public func uninstallDaemon() -> Bool {
        let shellCommand = [
            "launchctl bootout system/\(Self.daemonLabel) 2>/dev/null; true",
            "rm -f '\(Self.helperPath)' '\(Self.daemonPlistPath)' '\(Self.controlFilePath)'",
            "sed -i '' '/\(Self.markerStart)/,/\(Self.markerEnd)/d' /etc/hosts",
            "dscacheutil -flushcache",
            "killall -HUP mDNSResponder 2>/dev/null; true"
        ].joined(separator: " && ")

        let success = runAppleScriptWithAdmin(shellCommand)
        isDaemonInstalled = false
        return success
    }

    private func runAppleScriptWithAdmin(_ shellCommand: String) -> Bool {
        let escaped = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error {
            NSLog("Pomafocus admin command error: %@", error.description)
            return false
        }
        return true
    }

    // MARK: - PomodoroBlocking

    public func beginBlocking() {
        NSLog("Pomafocus beginBlocking: %d domains, isDaemonInstalled=%d", blockedDomains.count, isDaemonInstalled ? 1 : 0)
        guard !blockedDomains.isEmpty else {
            NSLog("Pomafocus beginBlocking: skipping - no domains")
            return
        }
        isBlocking = true
        hostsModifier.applyBlocking(domains: blockedDomains)
    }

    public func endBlocking() {
        guard isBlocking else { return }
        isBlocking = false
        hostsModifier.clearBlocking()
    }

    public var hasSelection: Bool {
        !blockedDomains.isEmpty
    }

    public var selectionSummary: String {
        let count = blockedDomains.count
        return count == 0 ? "No domains selected" : "\(count) domain\(count == 1 ? "" : "s") blocked"
    }

    // MARK: - Domain management

    public func addDomain(_ domain: String) {
        let cleaned = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty, !blockedDomains.contains(cleaned) else { return }
        blockedDomains.append(cleaned)
    }

    public func removeDomain(_ domain: String) {
        blockedDomains.removeAll { $0 == domain }
    }

    private func persistDomains() {
        defaults.set(blockedDomains, forKey: domainsKey)
    }

    // MARK: - /etc/hosts content generation

    nonisolated static func hostsBlockContent(for domains: [String]) -> String {
        var lines = [markerStart]
        for domain in domains {
            lines.append("127.0.0.1 \(domain)")
            lines.append("::1 \(domain)")
        }
        lines.append(markerEnd)
        return lines.joined(separator: "\n")
    }

    // MARK: - Daemon file generation

    nonisolated static func generateHelperScript() -> String {
        // No indentation - this becomes a real shell script file
        return "#!/bin/bash\n"
            + "set -euo pipefail\n"
            + "CONTROL_FILE=\"\(controlFilePath)\"\n"
            + "MARKER_START=\"\(markerStart)\"\n"
            + "MARKER_END=\"\(markerEnd)\"\n"
            + "HOSTS=\"/etc/hosts\"\n"
            + "\n"
            + "sed -i '' \"/${MARKER_START}/,/${MARKER_END}/d\" \"$HOSTS\"\n"
            + "\n"
            + "if [ -s \"$CONTROL_FILE\" ]; then\n"
            + "  echo \"$MARKER_START\" >> \"$HOSTS\"\n"
            + "  while IFS= read -r domain || [ -n \"$domain\" ]; do\n"
            + "    [ -z \"$domain\" ] && continue\n"
            + "    echo \"127.0.0.1 $domain\" >> \"$HOSTS\"\n"
            + "    echo \"::1 $domain\" >> \"$HOSTS\"\n"
            + "  done < \"$CONTROL_FILE\"\n"
            + "  echo \"$MARKER_END\" >> \"$HOSTS\"\n"
            + "fi\n"
            + "\n"
            + "dscacheutil -flushcache\n"
            + "killall -HUP mDNSResponder 2>/dev/null || true\n"
    }

    nonisolated static func generateDaemonPlist() -> String {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            + "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
            + "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
            + "<plist version=\"1.0\">\n"
            + "<dict>\n"
            + "  <key>Label</key>\n"
            + "  <string>\(daemonLabel)</string>\n"
            + "  <key>ProgramArguments</key>\n"
            + "  <array>\n"
            + "    <string>\(helperPath)</string>\n"
            + "  </array>\n"
            + "  <key>WatchPaths</key>\n"
            + "  <array>\n"
            + "    <string>\(controlFilePath)</string>\n"
            + "  </array>\n"
            + "  <key>RunAtLoad</key>\n"
            + "  <false/>\n"
            + "  <key>ThrottleInterval</key>\n"
            + "  <integer>2</integer>\n"
            + "</dict>\n"
            + "</plist>\n"
    }
}

// MARK: - Hosts file modification

protocol HostsFileModifier: Sendable {
    func applyBlocking(domains: [String])
    func clearBlocking()
}

final class DaemonHostsModifier: HostsFileModifier {
    func applyBlocking(domains: [String]) {
        let path = PomodoroBlocker.controlFilePath
        let content = domains.joined(separator: "\n")
        NSLog("Pomafocus: writing %d domains to %@", domains.count, path)
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Pomafocus: FAILED to write control file: %@", error.localizedDescription)
        }
    }

    func clearBlocking() {
        let path = PomodoroBlocker.controlFilePath
        NSLog("Pomafocus: clearing blocking (deleting %@)", path)
        try? FileManager.default.removeItem(atPath: path)
    }
}

final class MockHostsModifier: HostsFileModifier {
    private let _applyCount = LockedValue(0)
    private let _clearCount = LockedValue(0)
    private let _lastDomains = LockedValue<[String]>([])

    var applyCount: Int { _applyCount.value }
    var clearCount: Int { _clearCount.value }
    var lastDomains: [String] { _lastDomains.value }

    func applyBlocking(domains: [String]) {
        _applyCount.value += 1
        _lastDomains.value = domains
    }

    func clearBlocking() {
        _clearCount.value += 1
    }
}

private final class LockedValue<T>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()

    init(_ value: T) { _value = value }

    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); defer { lock.unlock() }; _value = newValue }
    }
}
#endif
