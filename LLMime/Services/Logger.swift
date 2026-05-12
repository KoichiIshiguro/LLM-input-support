import Foundation

enum Log {
    private static let logDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/LLMime", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let fileHandle: FileHandle? = {
        let path = logDir.appendingPathComponent("llmime.log")
        if !FileManager.default.fileExists(atPath: path.path) {
            FileManager.default.createFile(atPath: path.path, contents: nil)
        }
        let handle = try? FileHandle(forWritingTo: path)
        handle?.seekToEndOfFile()
        return handle
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static var logFilePath: String {
        logDir.appendingPathComponent("llmime.log").path
    }

    static func info(_ message: String) {
        write("INFO", message)
    }

    static func error(_ message: String) {
        write("ERROR", message)
    }

    private static func write(_ level: String, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] \(message)\n"
        NSLog("[LLMime] %@", message)
        if let data = line.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }

    static func setupCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            Log.error("CRASH: \(exception.name.rawValue) — \(exception.reason ?? "unknown")")
            Log.error("Stack: \(exception.callStackSymbols.joined(separator: "\n"))")
        }

        for sig: Int32 in [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP] {
            signal(sig) { s in
                Log.error("SIGNAL: \(s)")
                Thread.callStackSymbols.forEach { Log.error($0) }
                exit(s)
            }
        }

        Log.info("--- LLMime started (PID \(ProcessInfo.processInfo.processIdentifier)) ---")
    }

    static func trimIfNeeded() {
        let path = logDir.appendingPathComponent("llmime.log")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              let size = attrs[.size] as? Int, size > 5_000_000 else { return }
        guard let data = try? Data(contentsOf: path) else { return }
        let trimmed = data.suffix(2_000_000)
        try? trimmed.write(to: path)
        Log.info("Log trimmed (was \(size / 1024)KB)")
    }
}
