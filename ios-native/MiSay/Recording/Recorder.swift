import AVFoundation
import Foundation
import Observation

/// 方塊 M1：開始、停止、計時、音量。放在 App 層，不綁錄音面板（2026-11-04）。
/// 錄音中被打斷、換耳機、卡住，都自己接回同一個檔；接不回去時 `RecordingAlarm` 會響（組塊 S 第一批）。
/// 畫面只讀狀態，不碰引擎。
@Observable
final class Recorder {
    private static let watchIntervalSeconds: TimeInterval = 1

    private(set) var isRecording = false
    private(set) var pauseReason: PauseReason?
    /// 接回去了但還沒有新聲音；面板不能再寫「正在聽」。
    private(set) var isWaitingForSound = false
    private(set) var elapsedSeconds: Double = 0
    /// 最近一段的音量，0 到 1。
    private(set) var level: Double = 0
    private(set) var levels: [Double] = Array(repeating: 0, count: Recorder.levelHistoryCount)
    /// 空間快滿時還能錄幾分鐘；夠用時是 nil。
    private(set) var minutesLeftOnDisk: Int?
    /// 上一段錄音中間斷過幾次，完成面板要講。
    private(set) var lastGaps = CaptureWatch.Gaps()

    @ObservationIgnored private var capture: MicrophoneCapture?
    @ObservationIgnored private var watch = CaptureWatch(startedAt: Date())
    @ObservationIgnored private var watchTimer: Timer?
    private let systemEvents = RecordingSystemEvents()
    private let backgroundTime = BackgroundTimeHold()
    private let alarm = RecordingAlarm()

    /// App 被殺時來不及收掉的那則通知，重開就不用再響了。
    init() {
        alarm.cancel()
    }

    /// 檔案開著、但現在沒在收音。面板要換字、要給「繼續錄」。
    var isPaused: Bool {
        pauseReason != nil
    }

    /// 問權限（第一次會跳系統框）、開收音、開始寫檔。失敗就拋，什麼都不留。
    @MainActor
    func start() async throws {
        guard !isRecording else {
            return
        }
        lastGaps = CaptureWatch.Gaps()
        guard await AVAudioApplication.requestRecordPermission() else {
            throw Failure.microphoneDenied
        }
        let space = RecordingSpace.verdict(availableBytes: RecordingSpace.availableBytes())
        guard space != .full else {
            throw Failure.notEnoughSpace
        }
        try RecordingAudioSession.activate()
        do {
            try beginCapture()
        } catch {
            abandonStart()
            throw error
        }
        pauseReason = nil
        isWaitingForSound = false
        applySpace(space)
        isRecording = true
        startWatching()
        DiagnosticLog.shared.record("錄音開始，空間 \(space)")
    }

    /// 使用者按「繼續錄」。自動接回走 `tryReconnect`，這裡多一關：空間滿停下來的，要先有空間。
    @MainActor
    func resume() throws {
        guard isRecording else {
            throw Failure.notRecording
        }
        // 剛好自動接回了：這一下不用做事，也不算失敗。
        guard isPaused else {
            return
        }
        let space = RecordingSpace.verdict(availableBytes: RecordingSpace.availableBytes())
        guard space != .full else {
            throw Failure.notEnoughSpace
        }
        try connectAgain()
    }

    /// 停收音、補檔頭，回錄好的檔在哪。呼叫端負責搬去待轉錄。
    @MainActor
    func stop() throws -> URL {
        guard isRecording, let capture else {
            throw Failure.notRecording
        }
        stopWatching()
        isRecording = false
        pauseReason = nil
        isWaitingForSound = false
        minutesLeftOnDisk = nil
        lastGaps = watch.gaps
        self.capture = nil
        DiagnosticLog.shared.record(
            "錄音停止，\(Int(elapsedSeconds)) 秒，斷過 \(lastGaps.times) 次共 \(Int(lastGaps.seconds)) 秒"
        )
        resetMeters()
        defer { RecordingAudioSession.deactivate() }
        try capture.finish()
        return capture.url
    }
}

/// 開始與接回。
private extension Recorder {
    func beginCapture() throws {
        let fileURL = try Self.inProgressDirectoryURL().appending(path: Self.newFileName())
        let newCapture = try MicrophoneCapture(
            creatingAt: fileURL,
            onSamples: { [weak self] level, elapsed in
                DispatchQueue.main.async { [weak self] in
                    self?.publish(level: level, elapsed: elapsed)
                }
            },
            onEngineStopped: { [weak self] in
                self?.handleLostInput("硬體變動")
            }
        )
        capture = newCapture
        try newCapture.connect()
    }

    func abandonStart() {
        capture?.discardEmptyFile()
        capture = nil
        RecordingAudioSession.deactivate()
    }

    /// App 開著時這個物件一直活著；停止時就歸零，下次面板一打開計時才不會閃上一段的秒數。
    func resetMeters() {
        elapsedSeconds = 0
        level = 0
        levels = Array(repeating: 0, count: Self.levelHistoryCount)
    }

    func publish(level: Double, elapsed: Double) {
        guard isRecording else {
            return
        }
        self.level = level
        elapsedSeconds = elapsed
        levels.removeFirst()
        levels.append(level)
    }

    /// 接回同一個檔。成功後要等真的有新聲音，通知才會被往後推（見 `CaptureWatch`）。
    func connectAgain() throws {
        guard let capture else {
            throw Failure.notRecording
        }
        watch.noteReconnectAttempt(at: Date())
        try RecordingAudioSession.activate()
        try capture.connect()
        pauseReason = nil
        watch.noteConnected(at: Date())
        backgroundTime.end()
        DiagnosticLog.shared.record("收音接回，已錄 \(Int(elapsedSeconds)) 秒")
    }

    func tryReconnect() {
        do {
            try connectAgain()
        } catch {
            DiagnosticLog.shared.record("接回失敗 \(error)")
            // 打斷結束才把 App 叫醒時，上一段背景時間多半用完了；再要一段，10 秒後才試得到。
            backgroundTime.begin()
        }
    }

    func pause(_ reason: PauseReason) {
        pauseReason = reason
        isWaitingForSound = true
        capture?.disconnect()
        watch.noteCaptureLost(at: Date(), byteCount: capture?.writtenByteCount ?? 0)
        backgroundTime.begin()
        DiagnosticLog.shared.record("收音暫停 \(reason)，已錄 \(Int(elapsedSeconds)) 秒")
    }
}

/// 錄音中盯著：系統事件與每秒檢查。
private extension Recorder {
    func startWatching() {
        watch = CaptureWatch(startedAt: Date())
        let timer = Timer(timeInterval: Self.watchIntervalSeconds, repeats: true) { [weak self] _ in
            self?.checkOnCapture()
        }
        RunLoop.main.add(timer, forMode: .common)
        watchTimer = timer
        systemEvents.start(
            onInterruption: { [weak self] kind in
                self?.handleInterruption(kind)
            },
            onServicesReset: { [weak self] in
                self?.handleLostInput("音訊服務重置")
            },
            onBecameActive: { [weak self] in
                self?.handleBecameActive()
            }
        )
        alarm.pushBack()
    }

    func stopWatching() {
        watchTimer?.invalidate()
        watchTimer = nil
        systemEvents.stop()
        alarm.cancel()
        backgroundTime.end()
    }

    func handleInterruption(_ kind: AudioInterruption?) {
        guard isRecording, let kind else {
            return
        }
        DiagnosticLog.shared.record("打斷 \(kind)")
        switch kind {
        case .began:
            if pauseReason != .outOfSpace {
                pause(.interrupted)
            }
        case .endedCanResume, .endedCannotResume:
            if isPaused, pauseReason != .outOfSpace {
                tryReconnect()
            }
        }
    }

    func handleLostInput(_ cause: String) {
        guard isRecording, !isPaused else {
            return
        }
        DiagnosticLog.shared.record("收音斷了：\(cause)")
        let canRetryNow = watch.allowsImmediateReconnect(at: Date())
        pause(.lostInput)
        if canRetryNow {
            tryReconnect()
        }
    }

    /// 在背景接不回去時（系統可能不准），回到前景一定試一次。
    func handleBecameActive() {
        if isRecording, isPaused, pauseReason != .outOfSpace {
            tryReconnect()
        }
    }

    func checkOnCapture() {
        guard isRecording, let capture else {
            return
        }
        if capture.hasWriteFailure, pauseReason != .outOfSpace {
            pause(.outOfSpace)
            return
        }
        let decision = watch.check(
            byteCount: capture.writtenByteCount,
            isPaused: isPaused,
            canReconnect: pauseReason != .outOfSpace,
            now: Date()
        )
        isWaitingForSound = watch.isWaitingForSound
        if decision.shouldCheckSpace {
            applySpace(RecordingSpace.verdict(availableBytes: RecordingSpace.availableBytes()))
        }
        if decision.isStalled {
            handleLostInput("檔案沒有變長")
        } else if decision.shouldReconnect {
            tryReconnect()
        } else if decision.shouldPushBackAlarm {
            alarm.pushBack()
        }
    }

    func applySpace(_ space: RecordingSpace.Verdict) {
        switch space {
        case .plenty:
            minutesLeftOnDisk = nil
        case let .low(minutesLeft):
            minutesLeftOnDisk = minutesLeft
        case .full:
            minutesLeftOnDisk = 0
            if isRecording, pauseReason != .outOfSpace {
                DiagnosticLog.shared.record("空間不夠，剩 \(RecordingSpace.availableBytes() ?? -1) bytes")
                pause(.outOfSpace)
            }
        }
    }
}
