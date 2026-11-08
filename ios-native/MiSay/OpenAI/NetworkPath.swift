import Foundation
import Network

/// 方塊 M11：現在走的是不是會算流量的網路（行動網路、個人熱點）。給 S4-2「錄音中先整理只用 Wi-Fi」用。
/// 系統還沒回報之前當成會算流量：寧可晚一點送，不要偷用使用者的流量。
final class NetworkPath: @unchecked Sendable {
    static let shared = NetworkPath()

    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var expensive = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(isExpensive: path.isExpensive || path.status != .satisfied)
        }
        monitor.start(queue: DispatchQueue(label: "org.domyweb.misay.network"))
    }

    var isExpensive: Bool {
        lock.withLock { expensive }
    }

    private func update(isExpensive: Bool) {
        lock.withLock { expensive = isExpensive }
    }
}
