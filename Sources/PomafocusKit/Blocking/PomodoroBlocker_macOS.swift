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
    private let domainsKey = "pomafocus.blocking.domains"
    private var isBlocking = false
    private let hostsModifier: HostsFileModifier

    nonisolated static let markerStart = "# POMAFOCUS BLOCK START"
    nonisolated static let markerEnd = "# POMAFOCUS BLOCK END"
    nonisolated static let controlFilePath = "/usr/local/var/pomafocus/blocked-domains"
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

        let shellCommand = """
        mkdir -p /usr/local/var/pomafocus && \
        cat > '\(Self.helperPath)' << 'HELPER_EOF'
        \(helperScript)
        HELPER_EOF
        chmod 755 '\(Self.helperPath)' && \
        cat > '\(Self.daemonPlistPath)' << 'PLIST_EOF'
        \(plistContent)
        PLIST_EOF
        launchctl bootout system/\(Self.daemonLabel) 2>/dev/null; \
        launchctl bootstrap system '\(Self.daemonPlistPath)'
        """

        let escaped = shellCommand.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        if let error {
            NSLog("Pomafocus daemon install error: %@", error.description)
            return false
        }

        isDaemonInstalled = true
        return true
    }

    public func uninstallDaemon() -> Bool {
        let shellCommand = """
        launchctl bootout system/\(Self.daemonLabel) 2>/dev/null; \
        rm -f '\(Self.helperPath)' '\(Self.daemonPlistPath)' '\(Self.controlFilePath)' && \
        sed -i '' '/\(Self.markerStart)/,/\(Self.markerEnd)/d' /etc/hosts && \
        dscacheutil -flushcache && \
        killall -HUP mDNSResponder 2>/dev/null; true
        """

        let escaped = shellCommand.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        isDaemonInstalled = false
        return error == nil
    }

    // MARK: - PomodoroBlocking

    public func beginBlocking() {
        guard !blockedDomains.isEmpty else { return }
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
        return """
        #!/bin/bash
        set -euo pipefail
        CONTROL_FILE="\(controlFilePath)"
        MARKER_START="\(markerStart)"
        MARKER_END="\(markerEnd)"
        HOSTS="/etc/hosts"

        # Remove existing block
        sed -i '' "/${MARKER_START}/,/${MARKER_END}/d" "$HOSTS"

        # If control file exists and is non-empty, apply new block
        if [ -s "$CONTROL_FILE" ]; then
            echo "$MARKER_START" >> "$HOSTS"
            while IFS= read -r domain || [ -n "$domain" ]; do
                [ -z "$domain" ] && continue
                echo "127.0.0.1 $domain" >> "$HOSTS"
                echo "::1 $domain" >> "$HOSTS"
            done < "$CONTROL_FILE"
            echo "$MARKER_END" >> "$HOSTS"
        fi

        # Flush DNS cache
        dscacheutil -flushcache
        killall -HUP mDNSResponder 2>/dev/null || true
        """
    }

    nonisolated static func generateDaemonPlist() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(daemonLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(helperPath)</string>
            </array>
            <key>WatchPaths</key>
            <array>
                <string>\(controlFilePath)</string>
            </array>
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """
    }
}

// MARK: - Hosts file modification

protocol HostsFileModifier: Sendable {
    func applyBlocking(domains: [String])
    func clearBlocking()
}

/// Writes a control file that the LaunchDaemon watches.
/// When the file changes, the daemon applies /etc/hosts changes as root.
/// No admin prompt needed - just a file write.
final class DaemonHostsModifier: HostsFileModifier {
    func applyBlocking(domains: [String]) {
        let content = domains.joined(separator: "\n")
        writeControlFile(content)
    }

    func clearBlocking() {
        writeControlFile("")
    }

    private func writeControlFile(_ content: String) {
        let path = PomodoroBlocker.controlFilePath
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Pomafocus: failed to write control file: %@", error.localizedDescription)
        }
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
