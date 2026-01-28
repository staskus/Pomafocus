#if os(macOS)
import Foundation
import ServiceManagement
import Security

@MainActor
final class PrivilegedHelperManager {
    static let shared = PrivilegedHelperManager()

    private let helperBundleID = "com.staskus.pomafocus.mac.helper"
    private let helperToolPath = "/Library/PrivilegedHelperTools/com.staskus.pomafocus.mac.helper"
    private let helperPlistPath = "/Library/LaunchDaemons/com.staskus.pomafocus.mac.helper.plist"
    private var connection: NSXPCConnection?
    private var helperInstalledCache: Bool?

    private init() {}

    func applyHosts(_ contents: String, completion: @escaping @MainActor (Bool, String?) -> Void) {
        let completionHandler: @Sendable (Bool, String?) -> Void = { success, message in
            Task { @MainActor in
                completion(success, message)
            }
        }
        ensureHelperInstalled { [weak self] installed, errorMessage in
            guard let self, installed else {
                completionHandler(false, errorMessage)
                return
            }
            let connection = self.helperConnection()
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                completionHandler(false, error.localizedDescription)
            } as? PomafocusPrivilegedHelperProtocol

            proxy?.applyHosts(contents) { success, message in
                completionHandler(success, message)
            }
        }
    }

    private func ensureHelperInstalled(completion: @escaping (Bool, String?) -> Void) {
        if isHelperInstalled() {
            completion(true, nil)
            return
        }

        guard let authorizationRef = createAuthorizationRef() else {
            completion(false, "Authorization failed")
            return
        }

        var error: Unmanaged<CFError>?
        let blessed = SMJobBless(kSMDomainSystemLaunchd, helperBundleID as CFString, authorizationRef, &error)
        AuthorizationFree(authorizationRef, [])

        if blessed {
            helperInstalledCache = true
            completion(true, nil)
        } else {
            let message = error?.takeRetainedValue().localizedDescription ?? "Failed to install helper"
            completion(false, message)
        }
    }

    private func isHelperInstalled() -> Bool {
        if let cached = helperInstalledCache {
            return cached
        }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: helperToolPath) || fileManager.fileExists(atPath: helperPlistPath) {
            helperInstalledCache = true
            return true
        }
        guard let job = SMJobCopyDictionary(kSMDomainSystemLaunchd, helperBundleID as CFString) else {
            helperInstalledCache = false
            return false
        }
        let dict = job.takeRetainedValue() as NSDictionary
        let isInstalled = dict.count > 0
        helperInstalledCache = isInstalled
        return isInstalled
    }

    private func createAuthorizationRef() -> AuthorizationRef? {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)
        guard status == errAuthorizationSuccess, let authRef else { return nil }

        let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]
        let statusCopy = kSMRightBlessPrivilegedHelper.withCString { rightName in
            var authItem = AuthorizationItem(name: rightName, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &authItem) { authItemPointer in
                var authRights = AuthorizationRights(count: 1, items: authItemPointer)
                return AuthorizationCopyRights(authRef, &authRights, nil, flags, nil)
            }
        }

        guard statusCopy == errAuthorizationSuccess else {
            AuthorizationFree(authRef, [])
            return nil
        }
        return authRef
    }

    private func helperConnection() -> NSXPCConnection {
        if let connection {
            return connection
        }
        let connection = NSXPCConnection(machServiceName: helperBundleID, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: PomafocusPrivilegedHelperProtocol.self)
        connection.resume()
        self.connection = connection
        return connection
    }
}
#endif
