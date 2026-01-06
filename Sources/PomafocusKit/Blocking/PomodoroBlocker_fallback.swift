#if !os(iOS) && !os(macOS)
import Foundation
import Combine

@MainActor
public final class PomodoroBlocker: ObservableObject, PomodoroBlocking {
    public static let shared = PomodoroBlocker()

    private init() {}

    public func ensureAuthorization() async -> Bool { false }
    public func beginBlocking() {}
    public func endBlocking() {}
    public var hasSelection: Bool { false }
    public var selectionSummary: String { "" }
}
#endif
