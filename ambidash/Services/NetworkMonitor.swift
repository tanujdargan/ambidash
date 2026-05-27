import Network
import Foundation

@Observable
final class NetworkMonitor: @unchecked Sendable {
    static let shared = NetworkMonitor()

    var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.ambidash.network")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
}
