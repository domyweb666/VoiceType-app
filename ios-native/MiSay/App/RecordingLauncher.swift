import Foundation
import Observation

/// 「要開錄」的請求（K1）：捷徑、Siri、動作按鈕、控制中心要開一段新的。
/// K3 接著錄（「⋯ → 接著錄」與打字時「在這裡接著錄」）2026-11-24 Y4 起走文字稿頁自己的錄音面板，不經過這裡。
/// 請求丟到這裡，分頁列切到錄音頁，由首頁打開同一個錄音面板，錄音只有一個入口。
/// 上一段的面板還開著時先留著，收掉才開；留太久就算了，免得忽然開始錄。
@MainActor
@Observable
final class RecordingLauncher {
    enum Request: Equatable {
        case new
    }

    /// 現在拿這個請求怎麼辦。
    enum Decision: Equatable {
        case start
        case keep
        case drop
    }

    static let shared = RecordingLauncher()
    static let keepSeconds: TimeInterval = 120

    /// 首頁接手後清成 nil。
    private(set) var request: Request?
    /// 開著的錄音面板，首頁的和文字稿頁的都算。記身分不記個數：系統多叫一次出現或消失也不會數錯。
    private(set) var openPanels: Set<UUID> = []
    @ObservationIgnored private var requestedAt = Date.distantPast

    var hasOpenPanel: Bool {
        !openPanels.isEmpty
    }

    /// 正在錄就丟：不重開、也不等錄完再開一段。
    static func decision(
        requestedAt: Date,
        isRecording: Bool,
        isPanelOpen: Bool,
        now: Date
    ) -> Decision {
        if isRecording || now.timeIntervalSince(requestedAt) > keepSeconds {
            return .drop
        }
        return isPanelOpen ? .keep : .start
    }

    func ask(_ newRequest: Request, now: Date = Date()) {
        requestedAt = now
        request = newRequest
    }

    /// 開錄了，先前留著的就不要了。
    func forgetRequest() {
        request = nil
    }

    /// 輪到它開錄才交出來，交出來就清掉；該丟的在這裡丟掉。
    func take(isRecording: Bool, isPanelOpening: Bool, now: Date = Date()) -> Request? {
        guard let request else {
            return nil
        }
        let decision = Self.decision(
            requestedAt: requestedAt,
            isRecording: isRecording,
            isPanelOpen: hasOpenPanel || isPanelOpening,
            now: now
        )
        switch decision {
        case .start:
            self.request = nil
            return request
        case .drop:
            self.request = nil
            return nil
        case .keep:
            return nil
        }
    }

    /// 只看要不要切到錄音頁，不拿走請求。
    func canStart(isRecording: Bool, now: Date = Date()) -> Bool {
        guard request != nil else {
            return false
        }
        let decision = Self.decision(
            requestedAt: requestedAt,
            isRecording: isRecording,
            isPanelOpen: hasOpenPanel,
            now: now
        )
        return decision == .start
    }

    func panelOpened(_ id: UUID) {
        openPanels.insert(id)
    }

    func panelClosed(_ id: UUID) {
        openPanels.remove(id)
    }
}
