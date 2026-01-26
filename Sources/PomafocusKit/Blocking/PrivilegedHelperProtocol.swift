import Foundation

@objc protocol PomafocusPrivilegedHelperProtocol {
    func applyHosts(_ contents: String, withReply reply: @escaping (Bool, String?) -> Void)
}
