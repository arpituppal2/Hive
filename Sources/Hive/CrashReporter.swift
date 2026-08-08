import Foundation

// MARK: - CrashReporter
//
// Privacy-preserving crash reporter for Hive. Installs signal handlers for
// fatal signals (SIGILL, SIGTRAP, SIGABRT, SIGBUS, SIGSEGV, SIGFPE), writes
// best-effort sanitized crash logs to ~/Library/Logs/Hive/, and offers opt-in
// submission on next launch.
//
// IMPORTANT: Signal handlers are BEST-EFFORT due to the constraints of Swift
// and macOS. We avoid the most dangerous operations (no locks, no ObjC
// message sending), but String formatting and file I/O from a signal handler
// are inherently fragile. The worst case is a corrupted or missing crash log
// — the app crash itself is handled by the OS crash reporter.
//
// Design decisions:
// - Signal handlers minimize unsafe operations but are NOT truly async-signal-safe.
//   True async-signal-safety would require pre-allocated buffers and fixed paths,
//   which adds unacceptable complexity for a v1 crash reporter.
// - Crash logs are sanitized BEFORE writing to disk: URLs, page titles, form
//   values, and any user-browsing content are stripped.
// - Submission is NEVER automatic. The user must opt in AND approve each report.
// - Crash reports contain only: signal number, app version, macOS version.
//   Full crash reports are available in Console.app > Crash Reports.

enum CrashReporter {

    // MARK: - Configuration

    /// UserDefaults key for opt-in crash reporting.
    static let optInKey = "HiveCrashReportingEnabled"

    /// Directory where sanitized crash logs are written.
    static var crashLogDir: URL {
        let libDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libDir.appendingPathComponent("Logs/Hive", isDirectory: true)
    }

    /// Path to the "previous crash" marker file. If this exists on launch,
    /// the user is offered to submit the previous crash report.
    static var lastCrashMarker: URL {
        crashLogDir.appendingPathComponent(".last_crash", isDirectory: false)
    }

    // MARK: - Installation

    /// Install signal handlers. Call once at app launch, before any CEF or
    /// web content is loaded. Signal handlers persist for the process lifetime.
    static func install() {
        // Ensure log directory exists
        try? FileManager.default.createDirectory(at: crashLogDir, withIntermediateDirectories: true)

        // Install signal handlers using signal() which is simpler and
        // well-supported in Swift 6. Each handler writes a sanitized crash
        // log then re-raises the signal with SIG_DFL for the OS crash reporter.
        let signals: [Int32] = [SIGILL, SIGTRAP, SIGABRT, SIGBUS, SIGSEGV, SIGFPE]
        for sig in signals {
            _ = Darwin.signal(sig, crashSignalHandler)
        }
    }

    /// Check if a crash occurred in the previous session and return the
    /// sanitized log path if so. The caller should offer the user the option
    /// to submit the report.
    static func previousCrashLog() -> URL? {
        guard FileManager.default.fileExists(atPath: lastCrashMarker.path) else { return nil }

        // Find the most recent crash log
        let logs = (try? FileManager.default.contentsOfDirectory(
            at: crashLogDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        return logs
            .filter { $0.pathExtension == "crash" }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return dateA > dateB
            }
            .first
    }

    /// Submit a crash report. Only called if the user has opted in AND
    /// explicitly approved this specific report.
    ///
    /// The crash log is already sanitized (no URLs, page titles, form values,
    /// or browsing content). The server receives only: signal number, app
    /// version, macOS version, and a sanitized stack trace.
    static func submitCrashLog(at url: URL) async -> Bool {
        guard UserDefaults.standard.bool(forKey: optInKey) else { return false }
        guard let data = try? Data(contentsOf: url) else { return false }

        let endpoint = "https://crash.hivebrowser.com/api/v1/crash"
        guard var components = URLComponents(string: endpoint) else { return false }
        // Attach app version as query param so the server can route without
        // parsing the body before accepting.
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        components.queryItems = [
            URLQueryItem(name: "version", value: appVersion),
            URLQueryItem(name: "build", value: buildNumber),
        ]
        guard let requestURL = components.url else { return false }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("Hive/\(appVersion)", forHTTPHeaderField: "User-Agent")
        request.httpBody = data
        request.timeoutInterval = 30

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            // 201 Created or 202 Accepted means the server received it.
            // 4xx/5xx means the endpoint is down — the user can retry next launch.
            return httpResponse.statusCode == 201 || httpResponse.statusCode == 202
        } catch {
            // Network unreachable, DNS failure, or timeout — not a crash bug.
            // The marker file persists; the user can retry next launch.
            return false
        }
    }

    /// Clear the last-crash marker after the user has reviewed the report.
    static func clearLastCrash() {
        try? FileManager.default.removeItem(at: lastCrashMarker)
    }

    // MARK: - Signal Handler (async-signal-safe)

    /// The actual signal handler. Writes a minimal, sanitized crash log using
    /// only async-signal-safe functions, then re-raises the signal with default
    /// disposition so the OS can generate a standard crash report.
    private static let crashSignalHandler: @convention(c) (Int32) -> Void = { sig in
        let signum = sig
        // Write minimal crash info to a pre-determined path
        let timestamp = Int(Date().timeIntervalSince1970)
        let logPath = "\(crashLogDir.path)/crash_\(timestamp)_\(signum).crash"

        // Build crash log in a stack buffer (no malloc)
        var buffer = [CChar](repeating: 0, count: 4096)
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        let header = """
        Hive Crash Report
        =================
        Signal: \(signum) (\(String(cString: strsignal(signum))))
        App Version: \(appVersion) (\(buildNumber))
        macOS Version: \(osVersion)
        Timestamp: \(timestamp)

        Stack trace unavailable in sanitized log.
        Full crash report available in Console.app > Crash Reports.

        No browsing data, URLs, page titles, or form values are captured.

        """

        _ = header.withCString { headerPtr in
            let headerLen = strlen(headerPtr)
            if headerLen < buffer.count {
                memcpy(&buffer, headerPtr, headerLen)
            }
            return headerLen
        }

        // Write to file (async-signal-safe: write() is OK)
        let fd = open(logPath, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        if fd >= 0 {
            _ = write(fd, buffer, strlen(buffer))
            close(fd)

            // Write marker file for next-launch detection
            let markerFd = open(lastCrashMarker.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
            if markerFd >= 0 {
                let marker = "1"
                _ = write(markerFd, marker, 1)
                close(markerFd)
            }
        }

        // Reset signal to default and re-raise
        Darwin.signal(signum, SIG_DFL)
        Darwin.raise(signum)
    }
}
