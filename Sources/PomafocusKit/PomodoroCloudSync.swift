import CloudKit
import Foundation

@MainActor
protocol PomodoroCloudSyncing: AnyObject {
    var onStateChange: ((PomodoroSharedState) -> Void)? { get set }
    var onPreferencesChange: ((PomodoroPreferencesSnapshot) -> Void)? { get set }

    func start()
    func publish(state: PomodoroSharedState)
    func publish(preferences: PomodoroPreferencesSnapshot)
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool
}

struct CloudKitConfiguration {
    let containerIdentifier: String?
    let isEnabled: Bool

    static func fromBundle() -> CloudKitConfiguration {
        let bundle = Bundle.main
        let identifier = bundle.object(forInfoDictionaryKey: "PomafocusCloudKitContainer") as? String
        let enabledValue: Bool
        if let rawValue = bundle.object(forInfoDictionaryKey: "PomafocusCloudKitEnabled") {
            if let number = rawValue as? NSNumber {
                enabledValue = number.boolValue
            } else if let string = rawValue as? NSString {
                enabledValue = string.boolValue
            } else {
                enabledValue = false
            }
        } else {
            enabledValue = false
        }
        let sanitizedIdentifier = identifier?.isEmpty == false ? identifier : nil
        return CloudKitConfiguration(containerIdentifier: sanitizedIdentifier, isEnabled: enabledValue && sanitizedIdentifier != nil)
    }

    static var disabled: CloudKitConfiguration {
        CloudKitConfiguration(containerIdentifier: nil, isEnabled: false)
    }
}

@MainActor
final class CloudKitPomodoroSync: PomodoroCloudSyncing {
    private enum RecordType {
        static let state = "PomodoroState"
        static let preferences = "PomodoroPreferences"
    }

    private enum SubscriptionID {
        static let state = "PomafocusStateSubscription"
        static let preferences = "PomafocusPreferencesSubscription"
    }

    private let configuration: CloudKitConfiguration
    private let container: CKContainer?
    private let database: CKDatabase?
    private let stateRecordID = CKRecord.ID(recordName: RecordType.state)
    private let preferencesRecordID = CKRecord.ID(recordName: RecordType.preferences)
    private var hasStarted = false

    var onStateChange: ((PomodoroSharedState) -> Void)?
    var onPreferencesChange: ((PomodoroPreferencesSnapshot) -> Void)?

    init(configuration: CloudKitConfiguration = .fromBundle(), database: CKDatabase? = nil) {
        self.configuration = configuration
        if configuration.isEnabled, let identifier = configuration.containerIdentifier {
            let container = CKContainer(identifier: identifier)
            self.container = container
            self.database = database ?? container.privateCloudDatabase
        } else {
            self.container = nil
            self.database = nil
        }
    }

    func start() {
        guard configuration.isEnabled, !hasStarted else { return }
        guard container != nil, database != nil else {
            log("CloudKit disabled; falling back to ubiquitous store.")
            return
        }
        hasStarted = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.setupSubscriptionsAndFetch()
        }
    }

    func publish(state: PomodoroSharedState) {
        guard configuration.isEnabled else { return }
        guard let database else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let record = try await self.record(for: self.stateRecordID, recordType: RecordType.state, database: database)
                self.configure(record: record, with: state)
                _ = try await self.save(record: record)
            } catch {
                log("Failed to publish state: \(error)")
            }
        }
    }

    func publish(preferences: PomodoroPreferencesSnapshot) {
        guard configuration.isEnabled else { return }
        guard let database else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let record = try await self.record(for: self.preferencesRecordID, recordType: RecordType.preferences, database: database)
                self.configure(record: record, with: preferences)
                _ = try await self.save(record: record)
            } catch {
                log("Failed to publish preferences: \(error)")
            }
        }
    }

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard configuration.isEnabled,
              let database,
              let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return false
        }

        if let queryNotification = notification as? CKQueryNotification,
           let subscriptionID = queryNotification.subscriptionID {
            do {
                switch subscriptionID {
                case SubscriptionID.state:
                    try await fetchStateRecord(database: database)
                    return true
                case SubscriptionID.preferences:
                    try await fetchPreferencesRecord(database: database)
                    return true
                default:
                    return false
                }
            } catch {
                log("Failed to handle remote notification: \(error)")
                return false
            }
        }

        return false
    }

    private func setupSubscriptionsAndFetch() async {
        guard configuration.isEnabled,
              let container,
              let database else {
            log("CloudKit configuration disabled or missing.")
            return
        }

        do {
            if let identifier = configuration.containerIdentifier,
               !EntitlementChecker.hasICloudContainer(identifier) {
                log("Skipping CloudKit sync; entitlement for \(identifier) missing.")
                return
            }
            let status = try await container.accountStatus()
            guard status == .available else {
                log("Skipping CloudKit sync; account status = \(status.rawValue)")
                return
            }
            try await ensureSubscription(recordType: RecordType.state, subscriptionID: SubscriptionID.state, database: database)
            try await ensureSubscription(recordType: RecordType.preferences, subscriptionID: SubscriptionID.preferences, database: database)
            try await fetchStateRecord(database: database)
            try await fetchPreferencesRecord(database: database)
        } catch {
            log("Failed to set up CloudKit sync: \(error)")
        }
    }

    private func fetchStateRecord(database: CKDatabase? = nil) async throws {
        guard let database else { return }
        do {
            let record = try await fetch(recordID: stateRecordID, database: database)
            if let state = decodeState(from: record) {
                deliverState(state)
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Nothing synced yet.
        }
    }

    private func fetchPreferencesRecord(database: CKDatabase? = nil) async throws {
        guard let database else { return }
        do {
            let record = try await fetch(recordID: preferencesRecordID, database: database)
            if let snapshot = decodePreferences(from: record) {
                deliverPreferences(snapshot)
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Nothing synced yet.
        }
    }

    private func ensureSubscription(recordType: String, subscriptionID: String, database: CKDatabase? = nil) async throws {
        guard let database else { return }
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        _ = try await save(subscription: subscription, database: database)
    }

    private func record(for id: CKRecord.ID, recordType: String, database: CKDatabase? = nil) async throws -> CKRecord {
        guard let database else {
            throw CKError(.internalError)
        }
        do {
            return try await fetch(recordID: id, database: database)
        } catch let error as CKError where error.code == .unknownItem {
            return CKRecord(recordType: recordType, recordID: id)
        }
    }

    private func configure(record: CKRecord, with state: PomodoroSharedState) {
        record["duration"] = NSNumber(value: state.duration)
        record["startedAt"] = state.startedAt as NSDate?
        record["isRunning"] = NSNumber(value: state.isRunning)
        record["updatedAt"] = state.updatedAt as NSDate
        record["originIdentifier"] = state.originIdentifier as NSString
    }

    private func configure(record: CKRecord, with preferences: PomodoroPreferencesSnapshot) {
        record["minutes"] = NSNumber(value: preferences.minutes)
        record["deepBreathEnabled"] = NSNumber(value: preferences.deepBreathEnabled)
        record["updatedAt"] = preferences.updatedAt as NSDate
        record["originIdentifier"] = preferences.originIdentifier as NSString
    }

    private func decodeState(from record: CKRecord) -> PomodoroSharedState? {
        guard
            let durationNumber = record["duration"] as? NSNumber,
            let isRunningNumber = record["isRunning"] as? NSNumber,
            let updatedAt = record["updatedAt"] as? Date,
            let origin = record["originIdentifier"] as? String
        else {
            return nil
        }
        let startedAt = record["startedAt"] as? Date
        return PomodoroSharedState(
            duration: durationNumber.intValue,
            startedAt: startedAt,
            isRunning: isRunningNumber.boolValue,
            updatedAt: updatedAt,
            originIdentifier: origin
        )
    }

    private func decodePreferences(from record: CKRecord) -> PomodoroPreferencesSnapshot? {
        guard
            let minutesNumber = record["minutes"] as? NSNumber,
            let updatedAt = record["updatedAt"] as? Date,
            let origin = record["originIdentifier"] as? String
        else {
            return nil
        }

        return PomodoroPreferencesSnapshot(
            minutes: minutesNumber.intValue,
            deepBreathEnabled: (record["deepBreathEnabled"] as? NSNumber)?.boolValue ?? false,
            updatedAt: updatedAt,
            originIdentifier: origin
        )
    }

    private func deliverState(_ state: PomodoroSharedState) {
        onStateChange?(state)
    }

    private func deliverPreferences(_ snapshot: PomodoroPreferencesSnapshot) {
        onPreferencesChange?(snapshot)
    }

    private func fetch(recordID: CKRecord.ID, database: CKDatabase) async throws -> CKRecord {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            database.fetch(withRecordID: recordID) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: CKError(.unknownItem))
                }
            }
        }
    }

    private func save(record: CKRecord) async throws -> CKRecord {
        guard let database else {
            throw CKError(.internalError)
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            database.save(record) { savedRecord, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let savedRecord {
                    continuation.resume(returning: savedRecord)
                } else {
                    continuation.resume(throwing: CKError(.unknownItem))
                }
            }
        }
    }

    private func save(subscription: CKSubscription, database: CKDatabase) async throws -> CKSubscription {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKSubscription, Error>) in
            database.save(subscription) { savedSubscription, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let savedSubscription {
                    continuation.resume(returning: savedSubscription)
                } else {
                    continuation.resume(throwing: CKError(.unknownItem))
                }
            }
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        NSLog("[CloudKitPomodoroSync] %@", message)
        #endif
    }
}
