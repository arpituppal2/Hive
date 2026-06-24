import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

public struct HiveWatchMessage: Codable, Hashable, Sendable {
    public var query: String
    public var source: String
    public var timestamp: String

    public init(query: String, source: String = "watch", timestamp: String = ISO8601DateFormatter().string(from: Date())) {
        self.query = query
        self.source = source
        self.timestamp = timestamp
    }
}

#if canImport(WatchConnectivity)
@MainActor
public final class HiveWatchConnectivityHandler: NSObject, ObservableObject {
    public static let shared = HiveWatchConnectivityHandler()

    @Published public private(set) var lastReceivedQuery: String?
    @Published public private(set) var lastResponse: String?
    public var onReceiveQuery: ((String) async -> String)?

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    private override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    public func sendQueryFromWatch(_ query: String) {
        guard let session, session.activationState == .activated else { return }
        let message: [String: Any] = [
            "query": query,
            "source": "watch",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] reply in
                Task { @MainActor in
                    self?.lastResponse = reply["response"] as? String
                }
            }, errorHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }

    public func sendResponseToWatch(_ response: String, for query: String) {
        guard let session, session.activationState == .activated else { return }
        let message = ["response": String(response.prefix(400)), "query": query]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }
}

extension HiveWatchConnectivityHandler: WCSessionDelegate {
    public nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    #if os(iOS)
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    public nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let query = message["query"] as? String else { return }
        Task { @MainActor in
            self.lastReceivedQuery = query
            if let handler = self.onReceiveQuery {
                let response = await handler(query)
                self.sendResponseToWatch(response, for: query)
                self.lastResponse = response
            }
        }
    }

    public nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let query = message["query"] as? String else {
            replyHandler([:])
            return
        }
        Task { @MainActor in
            self.lastReceivedQuery = query
            let response: String
            if let handler = self.onReceiveQuery {
                response = await handler(query)
            } else {
                response = "Open Hive on your iPhone to process this query."
            }
            self.lastResponse = response
            replyHandler(["response": String(response.prefix(400))])
        }
    }
}
#else
@MainActor
public final class HiveWatchConnectivityHandler: ObservableObject {
    public static let shared = HiveWatchConnectivityHandler()
    @Published public private(set) var lastReceivedQuery: String?
    @Published public private(set) var lastResponse: String?
    public var onReceiveQuery: ((String) async -> String)?
    public func sendQueryFromWatch(_ query: String) {}
    public func sendResponseToWatch(_ response: String, for query: String) {}
}
#endif
