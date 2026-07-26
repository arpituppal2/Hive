import Testing
@testable import HiveCore

@Test func hiveCoreVersionIsRebuildBaseline() {
    #expect(HiveCore.version == "0.0.0-rebuild")
}
