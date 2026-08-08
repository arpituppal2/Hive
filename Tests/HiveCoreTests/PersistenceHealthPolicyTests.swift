import Testing
@testable import HiveCore

@Suite("PersistenceHealthPolicy")
struct PersistenceHealthPolicyTests {
    @Test("only a session failure is degraded and disclosed")
    func sessionOnly() {
        let policy = PersistenceHealthPolicy(
            knowledgeDegraded: false,
            auditDegraded: false,
            sessionDegraded: true
        )
        #expect(policy.isDegraded)
        #expect(policy.title == "Session storage unavailable")
        #expect(policy.detail.contains("durable session storage"))
    }

    @Test("all three stores are represented without hiding any failure")
    func allStores() {
        let policy = PersistenceHealthPolicy(
            knowledgeDegraded: true,
            auditDegraded: true,
            sessionDegraded: true
        )
        #expect(policy.isDegraded)
        #expect(policy.title == "Storage unavailable")
        #expect(policy.detail.contains("browser changes"))
    }

    @Test("healthy state remains quiet")
    func healthy() {
        let policy = PersistenceHealthPolicy(
            knowledgeDegraded: false,
            auditDegraded: false,
            sessionDegraded: false
        )
        #expect(!policy.isDegraded)
        #expect(policy.title == "Storage available")
    }

    @Test("a failed session write latches without clearing other failures")
    func failedSessionWriteLatches() {
        let healthy = PersistenceHealthPolicy(
            knowledgeDegraded: false,
            auditDegraded: false,
            sessionDegraded: false
        )
        #expect(healthy.afterSessionWrite(succeeded: false).sessionDegraded)
        #expect(!healthy.afterSessionWrite(succeeded: true).sessionDegraded)

        let alreadyDegraded = PersistenceHealthPolicy(
            knowledgeDegraded: true,
            auditDegraded: true,
            sessionDegraded: true
        )
        #expect(alreadyDegraded.afterSessionWrite(succeeded: true) == alreadyDegraded)
    }

    @Test("every failure combination has a non-empty disclosure")
    func everyCombinationIsCovered() {
        for knowledge in [false, true] {
            for audit in [false, true] {
                for session in [false, true] {
                    let policy = PersistenceHealthPolicy(
                        knowledgeDegraded: knowledge,
                        auditDegraded: audit,
                        sessionDegraded: session
                    )
                    #expect(!policy.title.isEmpty)
                    #expect(!policy.detail.isEmpty)
                    #expect(policy.isDegraded == (knowledge || audit || session))
                }
            }
        }
    }
}
