import Foundation

let helperBundleID = "com.staskus.pomafocus.mac.helper"

final class PrivilegedHelper: NSObject, PomafocusPrivilegedHelperProtocol, NSXPCListenerDelegate {
    private let listener: NSXPCListener

    override init() {
        listener = NSXPCListener(machServiceName: helperBundleID)
        super.init()
        listener.delegate = self
    }

    func run() {
        listener.resume()
        RunLoop.current.run()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: PomafocusPrivilegedHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func applyHosts(_ contents: String, withReply reply: @escaping (Bool, String?) -> Void) {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pomafocus-hosts-\(UUID().uuidString)")
        do {
            try contents.write(to: tempURL, atomically: true, encoding: .utf8)
            try installHosts(from: tempURL)
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
        try? FileManager.default.removeItem(at: tempURL)
    }

    private func installHosts(from tempURL: URL) throws {
        let install = Process()
        install.executableURL = URL(fileURLWithPath: "/usr/bin/install")
        install.arguments = ["-m", "644", tempURL.path, "/etc/hosts"]
        try install.run()
        install.waitUntilExit()
        guard install.terminationStatus == 0 else {
            throw NSError(domain: "PomafocusPrivilegedHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to install hosts file"])
        }

        let flush = Process()
        flush.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        flush.arguments = ["-flushcache"]
        try flush.run()
        flush.waitUntilExit()

        let mdns = Process()
        mdns.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        mdns.arguments = ["-HUP", "mDNSResponder"]
        try mdns.run()
        mdns.waitUntilExit()
    }
}

PrivilegedHelper().run()
