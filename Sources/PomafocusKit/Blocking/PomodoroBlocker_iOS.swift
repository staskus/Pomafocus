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
            if isBlockingActive {
                applyShield()
            }
        }
    }

    private let authorizationCenter = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    private let defaults: UserDefaults
    private let selectionKey = "pomafocus.screenTime.selection"
    private var sessionBlocking = false
    private var scheduleBlocking = false
    private var scheduleSelection = FamilyActivitySelection()

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
        sessionBlocking = true
        applyShield()
    }

    public func endBlocking() {
        guard sessionBlocking else { return }
        sessionBlocking = false
        applyShield()
    }

    public func beginScheduleBlocking(selection: FamilyActivitySelection) {
        scheduleSelection = selection
        scheduleBlocking = true
        applyShield()
    }

    public func endScheduleBlocking() {
        guard scheduleBlocking else { return }
        scheduleBlocking = false
        scheduleSelection = FamilyActivitySelection()
        applyShield()
    }

    public var hasSelection: Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty ||
        !selection.categoryTokens.isEmpty
    }

    public var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let domains = selection.webDomainTokens.count
        let categories = selection.categoryTokens.count
        return "Apps \(apps) • Websites \(domains) • Categories \(categories)"
    }

    private func applyShield() {
        let selection = effectiveSelection
        guard hasEffectiveSelection(selection) else {
            store.clearAllSettings()
            return
        }
        store.shield.applications = selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomainCategories = .specific(selection.categoryTokens)
    }

    private var isBlockingActive: Bool {
        sessionBlocking || scheduleBlocking
    }

    private var effectiveSelection: FamilyActivitySelection {
        var combined = FamilyActivitySelection()
        var hasCombined = false
        if sessionBlocking {
            combined = selection
            hasCombined = true
        }
        if scheduleBlocking {
            if hasCombined {
                combined = mergeSelections(primary: combined, secondary: scheduleSelection)
            } else {
                combined = scheduleSelection
            }
        }
        return combined
    }

    private func hasEffectiveSelection(_ selection: FamilyActivitySelection) -> Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty ||
        !selection.categoryTokens.isEmpty
    }

    private func mergeSelections(
        primary: FamilyActivitySelection,
        secondary: FamilyActivitySelection
    ) -> FamilyActivitySelection {
        var merged = primary
        merged.applicationTokens.formUnion(secondary.applicationTokens)
        merged.webDomainTokens.formUnion(secondary.webDomainTokens)
        merged.categoryTokens.formUnion(secondary.categoryTokens)
        return merged
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
