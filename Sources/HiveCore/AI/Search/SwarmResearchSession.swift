import Foundation

/// Main-actor coordinator for one visible Swarm research run.
///
/// This is deliberately UI-facing but SwiftUI-free: a browser view observes
/// snapshots, while the session owns provider task lifetime and retry/cancel
/// semantics. The reducer remains the only authority for research state.
@MainActor
public final class SwarmResearchSession {
    public typealias Observer = @MainActor (SwarmResearchState) -> Void

    public private(set) var state = SwarmResearchState()

    private var activeTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var lastProvider: (any WebSearchProvider)?
    private var lastQuery: String?
    private var lastFocusMode: WebSearchFocusMode = .webSearch
    private var observer: Observer?

    public init() {}

    deinit {
        activeTask?.cancel()
    }

    /// Starts a new run and immediately publishes its `.running` snapshot.
    /// Starting a new run invalidates and cancels any previous run.
    public func start(
        provider: any WebSearchProvider,
        query: String,
        focusMode: WebSearchFocusMode,
        observe: @escaping Observer
    ) {
        activeTask?.cancel()
        generation &+= 1
        let runGeneration = generation
        state = SwarmResearchState()
        lastProvider = provider
        lastQuery = query
        lastFocusMode = focusMode
        observer = observe
        publish()

        activeTask = Task { [weak self] in
            do {
                let result = try await provider.streamSearch(
                    query: query,
                    focusMode: focusMode
                ) { [weak self] event in
                    guard !Task.isCancelled else { return }
                    self?.apply(event, for: runGeneration)
                }

                guard let self,
                      self.generation == runGeneration,
                      !Task.isCancelled else { return }
                self.state.complete(with: result)
                self.publish()
                self.activeTask = nil
            } catch {
                guard let self,
                      self.generation == runGeneration,
                      !Task.isCancelled else { return }
                if self.isCancellationError(error) {
                    self.state.cancel()
                } else {
                    self.state.fail(error.localizedDescription)
                }
                self.publish()
                self.activeTask = nil
            }
        }
    }

    /// Stops the active run. Late provider events and completions are ignored.
    public func cancel() {
        guard state.phase == .running else { return }
        generation &+= 1
        activeTask?.cancel()
        activeTask = nil
        state.cancel()
        publish()
    }

    /// Repeats the last request with a fresh generation and the existing observer.
    /// Returns false when no previous request exists.
    @discardableResult
    public func retry() -> Bool {
        retry(observe: nil)
    }

    /// Repeats the last request while optionally replacing the observer. The
    /// replacement is used by a UI adapter whose placeholder/generation changed
    /// between attempts; the provider and query remain owned by this session.
    @discardableResult
    public func retry(observe newObserver: Observer?) -> Bool {
        guard let provider = lastProvider,
              let query = lastQuery,
              let currentObserver = newObserver ?? observer else { return false }
        start(provider: provider, query: query, focusMode: lastFocusMode, observe: currentObserver)
        return true
    }

    private func apply(_ event: WebSearchStreamEvent, for runGeneration: UInt64) {
        guard generation == runGeneration,
              state.phase == .running else { return }
        state.apply(event)
        publish()
    }

    private func publish() {
        observer?(state)
    }

    private func isCancellationError(_ error: Error) -> Bool {
        Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}
