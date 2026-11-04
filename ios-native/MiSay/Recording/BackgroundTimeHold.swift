import UIKit

/// 方塊 M1：音訊一斷，App 就不算在背景錄音，系統很快會把它暫停；跟系統要一點時間，才等得到打斷結束。
final class BackgroundTimeHold {
    private var task = UIBackgroundTaskIdentifier.invalid

    func begin() {
        guard task == .invalid else {
            return
        }
        task = UIApplication.shared.beginBackgroundTask(withName: "MiSayReconnect") { [weak self] in
            self?.end()
        }
    }

    /// 沒在等也可以叫。時間到系統會叫這裡，不結束 App 會被砍掉。
    func end() {
        guard task != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}
