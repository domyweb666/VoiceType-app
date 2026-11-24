import Foundation
import UIKit

/// 方塊 M1：`Recorder` 把錄音狀態丟到這裡就走，鎖定畫面與靈動島照著更新。
/// 系統那幾個呼叫在另一個工作裡照順序做：被拒絕、失敗、卡住，錄音都不等、也不知道。
/// 跟 `Recorder` 一樣只在主執行緒叫。
final class RecordingActivityPresenter {
    static let shared = RecordingActivityPresenter()

    private let commands: AsyncStream<RecordingActivityHost.Command>.Continuation
    private var plan = RecordingActivityPlan()

    private init() {
        let (stream, continuation) = AsyncStream.makeStream(of: RecordingActivityHost.Command.self)
        commands = continuation
        Task.detached {
            var host = RecordingActivityHost()
            for await command in stream {
                await host.handle(command)
            }
        }
    }

    /// App 一啟動叫一次：這時一定還沒開錄，畫面上有的都是上次被殺留下的。
    func endLeftovers() {
        commands.yield(.endLeftovers)
    }

    /// 開錄、每秒、一斷掉都會叫；多半什麼都不送。
    func recordingIsRunning(_ status: RecordingActivityPlan.Status) {
        let appState = UIApplication.shared.applicationState
        if let frame = plan.next(status, appState: appState, now: Date()) {
            commands.yield(.show(frame))
        }
    }

    func recordingDidStop() {
        plan = RecordingActivityPlan()
        commands.yield(.end)
    }
}
