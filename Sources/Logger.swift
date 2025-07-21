import Foundation

/// Simple logger that redirects stdout & stderr to a log file inside ~/Library/Logs/TextEnhancer/debug.log
final class Logger {
    static let shared = Logger()
    let logFileURL: URL

    private init() {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("TextEnhancer", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        logFileURL = logsDir.appendingPathComponent("debug.log")

        let path = (logFileURL.path as NSString).fileSystemRepresentation
        freopen(path, "a+", stdout)
        freopen(path, "a+", stderr)
        fputs("\n=== TextEnhancer log started: \(Date()) ===\n", stderr)
    }
} 