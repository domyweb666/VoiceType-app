import Foundation
import Observation

/// 「要開錄」的請求（K1、K3）：捷徑、Siri、動作按鈕要開一段新的；詳情頁「接著錄」要接在某一篇後面。
/// 請求丟到這裡，分頁列切到錄音頁，由首頁打開同一個錄音面板，錄音只有一個入口。
@MainActor
@Observable
final class RecordingLauncher {
    enum Request: Equatable {
        case new
        case append(to: UUID)
    }

    static let shared = RecordingLauncher()

    /// 首頁接手後清成 nil。
    var request: Request?
}
