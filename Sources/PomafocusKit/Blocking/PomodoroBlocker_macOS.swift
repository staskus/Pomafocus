#if os(macOS)
import AppKit
import Combine

@MainActor
public final class PomodoroBlocker: ObservableObject, PomodoroBlocking {
    public static let shared = PomodoroBlocker()

    @Published public private(set) var blockedWebsites: [String]

    private let defaults: UserDefaults
    private let storageKey = "pomafocus.mac.blockedWebsites"
    private let hostsModifier = HostsFileModifier()
    private var isBlocking = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.blockedWebsites = defaults.stringArray(forKey: storageKey) ?? []
    }

    public func ensureAuthorization() async -> Bool {
        true
    }

    public func beginBlocking() {
        guard !blockedWebsites.isEmpty else { return }
        isBlocking = true
        Task.detached { [blockedWebsites, hostsModifier] in
            do {
                try hostsModifier.applyBlock(for: blockedWebsites)
            } catch {
                NSLog("[PomodoroBlocker] Failed to apply hosts block: \(error.localizedDescription)")
            }
        }
    }

    public func endBlocking() {
        guard isBlocking else { return }
        isBlocking = false
        Task.detached { [hostsModifier] in
            do {
                try hostsModifier.applyBlock(for: [])
            } catch {
                NSLog("[PomodoroBlocker] Failed to clear hosts block: \(error.localizedDescription)")
            }
        }
    }

    public var hasSelection: Bool {
        !blockedWebsites.isEmpty
    }

    public var selectionSummary: String {
        hasSelection ? "Websites \(blockedWebsites.count)" : "No websites configured"
    }

    public func setBlockedWebsites(_ websites: [String]) {
        blockedWebsites = PomodoroBlocker.normalize(websites)
        defaults.set(blockedWebsites, forKey: storageKey)
        if isBlocking {
            beginBlocking()
        }
    }

    private static func normalize(_ websites: [String]) -> [String] {
        let sanitized = websites
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        return sanitized.filter { seen.insert($0).inserted }
    }
}
#endif
