#if os(iOS) && targetEnvironment(macCatalyst)
import Foundation

@MainActor
public final class PomodoroBlocker: ObservableObject, PomodoroBlocking {
    public static let shared = PomodoroBlocker()

    @Published public private(set) var blockedWebsites: [String]

    private let defaults: UserDefaults
    private let storageKey = "pomafocus.mac.blockedWebsites"
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
        // TODO: integrate system-level website blocking once Screen Time APIs are supported on macOS Catalyst.
    }

    public func endBlocking() {
        guard isBlocking else { return }
        isBlocking = false
    }

    public var hasSelection: Bool {
        !blockedWebsites.isEmpty
    }

    public var selectionSummary: String {
        hasSelection ? "Websites \(blockedWebsites.count)" : "No websites configured"
    }

    public func setBlockedWebsites(_ websites: [String]) {
        blockedWebsites = websites.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        defaults.set(blockedWebsites, forKey: storageKey)
    }
}
#endif
