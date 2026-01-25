#if os(iOS)
import Foundation
import Combine
@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings

@MainActor
public final class PomodoroBlocker: ObservableObject, PomodoroBlocking {
    public static let shared = PomodoroBlocker()

    @Published public var selection: FamilyActivitySelection {
        didSet {
            persistSelection()
            if isBlocking {
                applyShield()
            }
        }
    }

    public var overrideSelection: FamilyActivitySelection? {
        didSet {
            if isBlocking {
                applyShield()
            }
        }
    }

    private let authorizationCenter = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    private let defaults: UserDefaults
    private let selectionKey = "pomafocus.screenTime.selection"
    private var isBlocking = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selection = PomodoroBlocker.restoreSelection(from: defaults, key: selectionKey)
    }

    @discardableResult
    public func ensureAuthorization() async -> Bool {
        do {
            switch authorizationCenter.authorizationStatus {
            case .approved:
                return true
            case .denied, .notDetermined:
                try await authorizationCenter.requestAuthorization(for: .individual)
                return authorizationCenter.authorizationStatus == .approved
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    public func beginBlocking() {
        guard hasSelection else { return }
        isBlocking = true
        applyShield()
    }

    public func endBlocking() {
        guard isBlocking else { return }
        isBlocking = false
        store.clearAllSettings()
    }

    public var hasSelection: Bool {
        !activeSelection.applicationTokens.isEmpty ||
        !activeSelection.webDomainTokens.isEmpty ||
        !activeSelection.categoryTokens.isEmpty
    }

    public var selectionSummary: String {
        let apps = activeSelection.applicationTokens.count
        let domains = activeSelection.webDomainTokens.count
        let categories = activeSelection.categoryTokens.count
        return "Apps \(apps) • Websites \(domains) • Categories \(categories)"
    }

    private func applyShield() {
        guard hasSelection else {
            store.clearAllSettings()
            return
        }
        store.shield.applications = activeSelection.applicationTokens
        store.shield.webDomains = activeSelection.webDomainTokens
        store.shield.applicationCategories = .specific(activeSelection.categoryTokens)
        store.shield.webDomainCategories = .specific(activeSelection.categoryTokens)
    }

    private var activeSelection: FamilyActivitySelection {
        overrideSelection ?? selection
    }

    private func persistSelection() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: selectionKey)
    }

    private static func restoreSelection(from defaults: UserDefaults, key: String) -> FamilyActivitySelection {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return decoded
    }
}
#endif
