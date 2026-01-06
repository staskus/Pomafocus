#if os(macOS)
import Foundation

enum HostsFileError: Error, CustomStringConvertible {
    case scriptFailed(Int32, String)

    var description: String {
        switch self {
        case let .scriptFailed(code, output):
            return "Hosts modification failed (code \(code)): \(output)"
        }
    }
}

struct HostsFileModifier {
    func applyBlock(for domains: [String]) throws {
        let scriptURL = try makeScriptFile()
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        var components = [scriptURL.path]
        components.append(contentsOf: domains)
        let command = components
            .map(Self.shellEscape)
            .joined(separator: " ")
        let osaCommand = "do shell script \"\(command)\" with administrator privileges"

        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", osaCommand]

        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw HostsFileError.scriptFailed(process.terminationStatus, output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func makeScriptFile() throws -> URL {
        let script = """
        #!/bin/bash
        set -euo pipefail
        HOSTS_FILE="/etc/hosts"
        CLEANED="$(mktemp)"
        if [ -f "$HOSTS_FILE" ]; then
          awk 'BEGIN{skip=0}
          /^# BEGIN POMAFOCUS$/{skip=1;next}
          /^# END POMAFOCUS$/{skip=0;next}
          skip==0 {print}' "$HOSTS_FILE" > "$CLEANED"
        else
          touch "$CLEANED"
        fi

        if [ "$#" -gt 0 ]; then
          TMP_APPEND="$(mktemp)"
          cat "$CLEANED" > "$TMP_APPEND"
          echo "# BEGIN POMAFOCUS" >> "$TMP_APPEND"
          for domain in "$@"; do
            echo "127.0.0.1 $domain" >> "$TMP_APPEND"
            echo "::1 $domain" >> "$TMP_APPEND"
          done
          echo "# END POMAFOCUS" >> "$TMP_APPEND"
          mv "$TMP_APPEND" "$CLEANED"
        fi

        cat "$CLEANED" > "$HOSTS_FILE"
        rm "$CLEANED"
        dscacheutil -flushcache >/dev/null 2>&1 || true
        killall -HUP mDNSResponder >/dev/null 2>&1 || true
        """

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pomafocus-hosts-\(UUID().uuidString).sh")
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int16(0o755))], ofItemAtPath: url.path)
        return url
    }

    private static func shellEscape(_ value: String) -> String {
        if value.isEmpty { return "''" }
        return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
#endif
