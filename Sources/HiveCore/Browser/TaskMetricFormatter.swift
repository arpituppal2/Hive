import Foundation

// MARK: - TaskMetricFormatter
//
// Pure formatting rules for the Chrome-parity Task Manager: process memory
// and CPU values become the short, human strings Chrome shows in its task
// table. Deterministic — no locale-dependent byte formatters, so tests and
// UI agree on every platform.

public enum TaskMetricFormatter {

    /// Formats a process memory footprint in bytes the way Chrome does:
    /// "123 KB", "1.5 MB", "2.3 GB". `-1` (CEF's "no valid value") renders
    /// as "—". Values below 1 KB still round up to at least "1 KB". The
    /// POSIX locale keeps the decimal point stable on every machine.
    public static func memoryString(bytes: Int64) -> String {
        guard bytes >= 0 else { return "—" }
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1 {
            return String(format: "%.1f GB", locale: Locale(identifier: "en_US_POSIX"), gb)
        }
        if mb >= 1 {
            return String(format: "%.1f MB", locale: Locale(identifier: "en_US_POSIX"), mb)
        }
        if kb >= 1 {
            return String(format: "%.0f KB", locale: Locale(identifier: "en_US_POSIX"), kb.rounded())
        }
        return "1 KB"
    }

    /// Formats GPU memory with a distinct label so the column reads clearly.
    public static func gpuMemoryString(bytes: Int64) -> String {
        guard bytes >= 0 else { return "—" }
        return memoryString(bytes: bytes) + " GPU"
    }

    /// Formats CEF's CPU usage. CEF reports percent-of-one-core (range
    /// 0 … processors × 100%), so a 200 means two cores fully busy — Chrome's
    /// Task Manager shows exactly this. Clamped to 999% so a many-core burst
    /// can't overflow the column.
    public static func cpuString(cpuUsage: Double) -> String {
        let clamped = max(0, min(999, cpuUsage))
        return String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), clamped)
    }
}
