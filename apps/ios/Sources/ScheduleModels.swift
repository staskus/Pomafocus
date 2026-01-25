import Foundation
import FamilyControls

public enum ScheduleKind: String, Codable, CaseIterable {
    case focus
    case `break`

    var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .break: return "Break"
        }
    }
}

public enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    public var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

public struct BlockList: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var selection: FamilyActivitySelection

    public init(id: UUID = UUID(), name: String, selection: FamilyActivitySelection) {
        self.id = id
        self.name = name
        self.selection = selection
    }
}

public struct ScheduleBlock: Identifiable, Codable {
    public var id: UUID
    public var title: String
    public var kind: ScheduleKind
    public var startMinutes: Int
    public var durationMinutes: Int
    public var days: Set<Weekday>
    public var blockListID: UUID?
    public var selection: FamilyActivitySelection?

    public init(
        id: UUID = UUID(),
        title: String,
        kind: ScheduleKind,
        startMinutes: Int,
        durationMinutes: Int,
        days: Set<Weekday>,
        blockListID: UUID? = nil,
        selection: FamilyActivitySelection? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.startMinutes = startMinutes
        self.durationMinutes = durationMinutes
        self.days = days
        self.blockListID = blockListID
        self.selection = selection
    }
}

public struct FocusSchedule: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var blocks: [ScheduleBlock]

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool,
        blocks: [ScheduleBlock]
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.blocks = blocks
    }
}

extension ScheduleBlock {
    var endMinutes: Int {
        max(startMinutes, startMinutes + durationMinutes)
    }

    func applies(to weekday: Weekday) -> Bool {
        days.isEmpty || days.contains(weekday)
    }
}
