import Foundation

/// Simple logger that redirects `stdout` / `stderr` to a persistent log file in
/// `~/Library/Logs/TextEnhancer/debug.log`.
/// Initialising the shared instance once, early in app launch, is enough to capture all future `print` / `NSLog`
/// output.
final class Logger {
    static let shared = Logger()

    /// Location of the log file written by the logger.
    let logFileURL: URL

    private init() {
        // Build Logs/TextEnhancer directory under the user's Library
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("TextEnhancer", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        logFileURL = logsDir.appendingPathComponent("debug.log")

        // Redirect both stdout and stderr to the same log file (append-mode)
        let path = (logFileURL.path as NSString).fileSystemRepresentation
        freopen(path, "a+", stdout)
        freopen(path, "a+", stderr)

        // Timestamp header for each session
        let header = "\n=== TextEnhancer log started: \(Date()) ===\n"
        fputs(header, stderr)
    }
}
