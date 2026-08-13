import Foundation
import Testing
@testable import HiveCore

@Suite("TaskMetricFormatter")
struct TaskMetricFormatterTests {

    // MARK: - Memory

    @Test func bytesFormatAsKB() {
        #expect(TaskMetricFormatter.memoryString(bytes: 0) == "1 KB")
        #expect(TaskMetricFormatter.memoryString(bytes: 1024) == "1 KB")
        #expect(TaskMetricFormatter.memoryString(bytes: 1536) == "2 KB")
    }

    @Test func megabytesFormatWithOneDecimal() {
        #expect(TaskMetricFormatter.memoryString(bytes: 1024 * 1024) == "1.0 MB")
        #expect(TaskMetricFormatter.memoryString(bytes: Int64(1.5 * 1024 * 1024)) == "1.5 MB")
    }

    @Test func gigabytesFormatWithOneDecimal() {
        #expect(TaskMetricFormatter.memoryString(bytes: 1024 * 1024 * 1024) == "1.0 GB")
        #expect(TaskMetricFormatter.memoryString(bytes: Int64(2.25 * 1024 * 1024 * 1024)) == "2.2 GB")
    }

    @Test func unavailableMemoryIsEmDash() {
        #expect(TaskMetricFormatter.memoryString(bytes: -1) == "—")
        #expect(TaskMetricFormatter.gpuMemoryString(bytes: -1) == "—")
    }

    @Test func gpuMemoryCarriesLabel() {
        #expect(TaskMetricFormatter.gpuMemoryString(bytes: 512 * 1024 * 1024) == "512.0 MB GPU")
    }

    // MARK: - CPU

    @Test func cpuIsPercentOfOneCore() {
        // 100 = one core fully busy (Chrome shows 100%).
        #expect(TaskMetricFormatter.cpuString(cpuUsage: 100) == "100.0%")
        // 12.5 = one-eighth of a core.
        #expect(TaskMetricFormatter.cpuString(cpuUsage: 12.5) == "12.5%")
        // 200 = two cores fully busy (multi-core, like Chrome).
        #expect(TaskMetricFormatter.cpuString(cpuUsage: 200) == "200.0%")
    }

    @Test func cpuClampsToZeroAndUpperBound() {
        #expect(TaskMetricFormatter.cpuString(cpuUsage: -5) == "0.0%")
        // A many-core burst can exceed 999% only pathologically; clamp it.
        #expect(TaskMetricFormatter.cpuString(cpuUsage: 5000) == "999.0%")
    }
}
