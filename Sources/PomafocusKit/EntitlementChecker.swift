#if os(macOS)
import Foundation
import Security

public enum EntitlementChecker {
    public static var hasPushEntitlement: Bool {
        boolEntitlement(for: "com.apple.developer.aps-environment")
    }

    public static func hasICloudContainer(_ identifier: String) -> Bool {
        guard let containers = entitlementValue(for: "com.apple.developer.icloud-container-identifiers") as? [String] else {
            return false
        }
        return containers.contains(identifier)
    }

    private static func boolEntitlement(for key: String) -> Bool {
        if let boolValue = entitlementValue(for: key) as? Bool {
            return boolValue
        }
        if let stringValue = entitlementValue(for: key) as? String {
            return !stringValue.isEmpty
        }
        if let arrayValue = entitlementValue(for: key) as? [Any] {
            return !arrayValue.isEmpty
        }
        return false
    }

    private static func entitlementValue(for key: String) -> Any? {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return nil
        }
        return SecTaskCopyValueForEntitlement(task, key as CFString, nil)
    }
}
#else
public enum EntitlementChecker {
    public static var hasPushEntitlement: Bool { true }
    public static func hasICloudContainer(_ identifier: String) -> Bool { true }
}
#endif
