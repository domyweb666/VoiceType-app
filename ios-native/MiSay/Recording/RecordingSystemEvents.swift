import AVFoundation
import UIKit

/// 方塊 M1：錄音中要聽的系統事件。開始錄才聽，停止就不聽；都在主執行緒回呼。
final class RecordingSystemEvents {
    private var observers: [NSObjectProtocol] = []

    func start(
        onInterruption: @escaping (AudioInterruption?) -> Void,
        onServicesReset: @escaping () -> Void,
        onBecameActive: @escaping () -> Void
    ) {
        stop()
        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { notification in
                onInterruption(AudioInterruption(userInfo: notification.userInfo))
            },
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: .main
            ) { _ in
                onServicesReset()
            },
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { notification in
                // 只留紀錄：換耳機要不要重建，由引擎自己的通知決定（`MicrophoneCapture`）。
                let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                DiagnosticLog.shared.record("音訊路徑變動 \(reason ?? 0)")
            },
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                onBecameActive()
            },
        ]
    }

    func stop() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
    }
}
