#if os(macOS)
import AppKit
import Foundation

@MainActor
public final class PomodoroBlocker: ObservableObject, PomodoroBlocking {
    public static let shared = PomodoroBlocker()

    @Published public var blockedDomains: [String] {
        didSet { persistDomains() }
    }

    private let defaults: UserDefaults
    private let domainsKey = "pomafocus.blocking.domains"
    private var isBlocking = false
    private let hostsModifier: HostsFileModifier

    nonisolated static let markerStart = "# POMAFOCUS BLOCK START"
    nonisolated static let markerEnd = "# POMAFOCUS BLOCK END"

    init(
        defaults: UserDefaults = .standard,
        hostsModifier: HostsFileModifier = AppleScriptHostsModifier()
    ) {
        self.defaults = defaults
        self.hostsModifier = hostsModifier
        self.blockedDomains = defaults.stringArray(forKey: domainsKey) ?? []
    }

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

    nonisolated static func shellApplyCommand(domains: [String]) -> String {
        let content = hostsBlockContent(for: domains)
        let escaped = content.replacingOccurrences(of: "'", with: "'\\''")
        return """
        sed -i '' '/\(markerStart)/,/\(markerEnd)/d' /etc/hosts && \
        printf '%s\\n' '\(escaped)' >> /etc/hosts && \
        dscacheutil -flushcache && \
        killall -HUP mDNSResponder 2>/dev/null; true
        """
    }

    nonisolated static func shellClearCommand() -> String {
        return """
        sed -i '' '/\(markerStart)/,/\(markerEnd)/d' /etc/hosts && \
        dscacheutil -flushcache && \
        killall -HUP mDNSResponder 2>/dev/null; true
        """
    }
}

// MARK: - Hosts file modification

protocol HostsFileModifier: Sendable {
    func applyBlocking(domains: [String])
    func clearBlocking()
}

final class AppleScriptHostsModifier: HostsFileModifier {
    func applyBlocking(domains: [String]) {
        let shell = PomodoroBlocker.shellApplyCommand(domains: domains)
        runWithAdminPrivileges(shell)
    }

    func clearBlocking() {
        let shell = PomodoroBlocker.shellClearCommand()
        runWithAdminPrivileges(shell)
    }

    private func runWithAdminPrivileges(_ shellCommand: String) {
        let escaped = shellCommand.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error {
            NSLog("Pomafocus hosts blocking error: %@", error.description)
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
