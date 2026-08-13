import Foundation
import Testing
@testable import HiveCore

@Suite("MemoryAdmission")
struct MemoryAdmissionTests {
    @Test func modelExtractionIsCandidateAndNeverDurable() {
        let admission = MemoryAdmissionPolicy.modelExtraction(isPrivate: false)
        #expect(admission == .candidate)
        #expect(admission?.isDurable == false)
    }

    @Test func privateModelExtractionIsRejected() {
        #expect(MemoryAdmissionPolicy.modelExtraction(isPrivate: true) == nil)
    }

    @Test func userAuthoredCaptureIsDurableWhenNonPrivate() {
        let admission = MemoryAdmissionPolicy.userAuthoredCapture(isPrivate: false)
        #expect(admission == .durable)
        #expect(admission?.isDurable == true)
    }

    @Test func privateUserAuthoredCaptureIsRejected() {
        #expect(MemoryAdmissionPolicy.userAuthoredCapture(isPrivate: true) == nil)
    }

    @Test func admissionRoundTripsAsStableWireValue() throws {
        let data = try JSONEncoder().encode(MemoryAdmission.candidate)
        let decoded = try JSONDecoder().decode(MemoryAdmission.self, from: data)
        #expect(decoded == .candidate)
        #expect(String(data: data, encoding: .utf8) == "\"candidate\"")
    }
}
