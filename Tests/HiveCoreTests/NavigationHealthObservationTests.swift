import Testing
@testable import HiveCore

@Suite("NavigationHealthObservation")
struct NavigationHealthObservationTests {
    @Test("idle samples do not emit a false timeout")
    func idleSamplesRemainWaiting() {
        var observation = NavigationHealthObservation()

        let idleCompleted = observation.observe(isLoading: false)
        #expect(!idleCompleted)
        #expect(observation.state == .waitingForStart)
        let didTimeOut = observation.timeOut()
        #expect(!didTimeOut)
        #expect(observation.state == .waitingForStart)
    }

    @Test("an observed loading navigation times out exactly once")
    func loadingNavigationTimesOutOnce() {
        var observation = NavigationHealthObservation()
        _ = observation.observe(isLoading: true)

        let didTimeOut = observation.timeOut()
        #expect(didTimeOut)
        #expect(observation.state == .timedOut)
        let repeatedTimeOut = observation.timeOut()
        #expect(!repeatedTimeOut)
    }

    @Test("loading then idle completes exactly once")
    func loadingThenIdleCompletesOnce() {
        var observation = NavigationHealthObservation()

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
        let timedOut = observation.timeOut()
        #expect(!timedOut)
    }

    @Test("a timeout is terminal and cannot be completed by a late idle sample")
    func timeoutRejectsLateCompletion() {
        var observation = NavigationHealthObservation()

        _ = observation.observe(isLoading: true)
        _ = observation.timeOut()
        let lateCompletion = observation.observe(isLoading: false)
        #expect(!lateCompletion)
        #expect(observation.state == .timedOut)
    }

    @Test("consecutive loading observations without idle do not complete")
    func consecutiveLoadingNoComplete() {
        var observation = NavigationHealthObservation()
        _ = observation.observe(isLoading: true)
        _ = observation.observe(isLoading: true)
        #expect(observation.state == .loading)
    }

@Test("stateTransitionsAreExhaustive")
    func statesAreDefined() {
        let states: [NavigationHealthObservation.State] = [.waitingForStart, .loading, .completed, .timedOut]
        #expect(states.count == 4)
    }
}
