#if os(macOS)
import Foundation
import Combine

/// macOS currently ships without local blocking; this stub keeps the cross-platform
/// interfaces satisfied while we focus on the iOS experience.
@MainActor
public final class PomodoroBlocker: ObservableObject, PomodoroBlocking {
    public static let shared = PomodoroBlocker()

    private init() {}

    public func ensureAuthorization() async -> Bool { false }
    public func beginBlocking() {}
    public func endBlocking() {}
    public var hasSelection: Bool { false }
    public var selectionSummary: String { "Blocking unavailable on macOS" }
}
#endif
