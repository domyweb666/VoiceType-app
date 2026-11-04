import Foundation

/// 方塊 M1：看錄音有沒有在動，決定什麼時候接回、什麼時候把「沒在錄」的通知往後推、什麼時候看空間。
/// 純邏輯不碰硬體，單元測試測得到；`Recorder` 每秒問它一次，照回答做事。
struct CaptureWatch {
    /// 這次檢查要做什麼。
    struct Decision: Equatable {
        var isStalled = false
        var shouldReconnect = false
        var shouldPushBackAlarm = false
        var shouldCheckSpace = false
    }

    /// 錄音中間斷過幾次、共多久（完成面板要講）。要等聲音真的回來才算一次。
    struct Gaps: Equatable {
        var times = 0
        var seconds: TimeInterval = 0
    }

    /// 系統一段緩衝約 0.1 秒，5 秒沒新資料一定是出事了。
    static let stallLimitSeconds: TimeInterval = 5
    /// 打斷結束的通知不保證會來（Apple 文件），所以定時自己試；太密會跟 Siri 這類搶音訊。
    static let reconnectRetrySeconds: TimeInterval = 10
    /// 接上不到這麼久又斷，算一次彈跳。
    static let bounceLimitSeconds: TimeInterval = 2
    /// 連續彈跳這麼多次就不馬上重接，改等定時重試，免得引擎一直開關打轉。
    static let maxBounces = 3
    static let alarmPushSeconds: TimeInterval = 30
    static let spaceCheckSeconds: TimeInterval = 30

    private(set) var gaps = Gaps()
    private var lastByteCount: UInt32 = 0
    private var lastGrowthAt: Date
    private var lastReconnectAttemptAt: Date
    private var lastAlarmPushAt: Date
    private var lastSpaceCheckAt: Date
    private var gapStartedAt: Date?
    private var lastConnectedAt: Date
    private var bounceCount = 0

    init(startedAt now: Date) {
        lastConnectedAt = now
        lastGrowthAt = now
        lastReconnectAttemptAt = now
        lastAlarmPushAt = now
        lastSpaceCheckAt = now
    }

    /// `canReconnect` 是 false 時（空間滿了）不自己接回，等使用者按。
    mutating func check(
        byteCount: UInt32,
        isPaused: Bool,
        canReconnect: Bool,
        now: Date
    ) -> Decision {
        var decision = Decision()
        if now.timeIntervalSince(lastSpaceCheckAt) >= Self.spaceCheckSeconds {
            decision.shouldCheckSpace = true
            lastSpaceCheckAt = now
        }
        if isPaused {
            let waited = now.timeIntervalSince(lastReconnectAttemptAt)
            if canReconnect, waited >= Self.reconnectRetrySeconds {
                decision.shouldReconnect = true
                lastReconnectAttemptAt = now
            }
            return decision
        }
        let hasGrown = byteCount > lastByteCount
        if hasGrown {
            noteGrowth(byteCount: byteCount, now: now)
        }
        if now.timeIntervalSince(lastGrowthAt) >= Self.stallLimitSeconds {
            decision.isStalled = true
        } else if hasGrown, now.timeIntervalSince(lastAlarmPushAt) >= Self.alarmPushSeconds {
            // 一定要真的有新聲音才往後推：接上了卻沒聲音時，通知要照樣響。
            decision.shouldPushBackAlarm = true
            lastAlarmPushAt = now
        }
        return decision
    }

    /// 斷了之後還沒寫進新資料。
    var isWaitingForSound: Bool {
        gapStartedAt != nil
    }

    /// 收音斷了。`byteCount` 是斷之前寫到的量，接回後比這個多才算新聲音（最後一秒可能還沒被 `check` 看過）。
    /// 打斷剛開始不馬上搶音訊，第一次試接等 `reconnectRetrySeconds`。
    mutating func noteCaptureLost(at now: Date, byteCount: UInt32) {
        if gapStartedAt == nil {
            gapStartedAt = now
        }
        lastByteCount = max(lastByteCount, byteCount)
        lastReconnectAttemptAt = now
    }

    /// 收音斷了要不要馬上重接。接上就斷第一下常見（硬體還在穩定），連續太多次才慢下來。
    mutating func allowsImmediateReconnect(at now: Date) -> Bool {
        if now.timeIntervalSince(lastConnectedAt) < Self.bounceLimitSeconds {
            bounceCount += 1
        } else {
            bounceCount = 0
        }
        return bounceCount < Self.maxBounces
    }

    mutating func noteReconnectAttempt(at now: Date) {
        lastReconnectAttemptAt = now
    }

    /// 接上了，給它一點時間出聲音，才開始算卡住。
    mutating func noteConnected(at now: Date) {
        lastConnectedAt = now
        lastGrowthAt = now
    }

    private mutating func noteGrowth(byteCount: UInt32, now: Date) {
        lastByteCount = byteCount
        lastGrowthAt = now
        if let gapStartedAt {
            gaps.times += 1
            gaps.seconds += now.timeIntervalSince(gapStartedAt)
        }
        gapStartedAt = nil
    }
}
