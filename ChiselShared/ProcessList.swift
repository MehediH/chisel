import Foundation

/// AI coding tool process signatures.
/// Matched against the executable path of the process making the connection.
enum ChiselProcessList {
    struct ProcessSignature {
        let name: String
        let pathMatches: [String]  // substring matches against executable path
    }

    static let blocked: [ProcessSignature] = [
        ProcessSignature(name: "Cursor", pathMatches: [
            "Cursor.app",
            "cursor.app",
        ]),
        ProcessSignature(name: "Windsurf", pathMatches: [
            "Windsurf.app",
            "windsurf.app",
        ]),
        ProcessSignature(name: "Claude Code", pathMatches: [
            "/claude",
            "claude-code",
        ]),
        ProcessSignature(name: "GitHub Copilot", pathMatches: [
            "copilot-agent",
            "copilot-language-server",
            "github-copilot",
        ]),
        ProcessSignature(name: "Tabnine", pathMatches: [
            "tabnine",
            "TabNine",
        ]),
        ProcessSignature(name: "Codeium", pathMatches: [
            "codeium",
            "Codeium",
        ]),
        ProcessSignature(name: "Supermaven", pathMatches: [
            "supermaven",
            "Supermaven",
        ]),
        ProcessSignature(name: "Amazon Q", pathMatches: [
            "amazon-q",
            "codewhisperer",
        ]),
        ProcessSignature(name: "Sourcegraph Cody", pathMatches: [
            "cody",
            "sourcegraph",
        ]),
    ]

    /// Check if an executable path matches any blocked AI tool.
    static func isBlocked(executablePath: String) -> Bool {
        for process in blocked {
            for pattern in process.pathMatches {
                if executablePath.localizedCaseInsensitiveContains(pattern) {
                    return true
                }
            }
        }
        return false
    }

    /// Return the name of the matched tool, or nil.
    static func matchedToolName(executablePath: String) -> String? {
        for process in blocked {
            for pattern in process.pathMatches {
                if executablePath.localizedCaseInsensitiveContains(pattern) {
                    return process.name
                }
            }
        }
        return nil
    }
}
