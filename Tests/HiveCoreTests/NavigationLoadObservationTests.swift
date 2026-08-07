import Testing
@testable import HiveCore

@Suite("NavigationLoadObservation")
struct NavigationLoadObservationTests {
    @Test("already idle does not count as completion")
    func idleBeforeStartIsNotCompletion() {
        var observation = NavigationLoadObservation()

        let completed = observation.observe(isLoading: false)
        #expect(!completed)
        #expect(observation.state == .waitingForStart)
    }

    @Test("completion requires a loading to idle transition")
    func loadingThenIdleCompletesOnce() {
        var observation = NavigationLoadObservation()

        let started = observation.observe(isLoading: true)
        #expect(!started)
        #expect(observation.state == .loading)
        let stillLoading = observation.observe(isLoading: true)
        #expect(!stillLoading)
        let completed = observation.observe(isLoading: false)
        #expect(completed)
        #expect(observation.state == .completed)
        let repeatedCompletion = observation.observe(isLoading: false)
        #expect(!repeatedCompletion)
    }

    @Test("a load that has not started remains pending")
    func repeatedIdleSamplesRemainPending() {
        var observation = NavigationLoadObservation()

        for _ in 0..<4 {
            let completed = observation.observe(isLoading: false)
            #expect(!completed)
        }
        #expect(observation.state == .waitingForStart)
    }
}
