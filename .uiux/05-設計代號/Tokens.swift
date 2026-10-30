// 米說 設計代號（2026-10-31，v1）
//
// 規則：畫面程式只准用這裡的語意代號（Token.*）。色碼、字級、間距、動畫數字
// 只准出現在這個檔案與顏色資源裡。提交前自動檢查會擋（見 使用規則.md 最後一節）。
//
// 數字來源：顏色抄自網頁版 docs/index.html 再依 對比檢查表.md 調過；
// 間距、圓角、點擊範圍抄自 03-線框；動態、觸覺抄自 04-手感/參數表.md。
//
// 如果技術選型留在 Flutter：語意名稱照抄成 Dart，數值一個字都不改。
//
// ⚠️ 會過時：@ScaledMetric、.sensoryFeedback、彈簧的 duration/bounce 寫法、
// 系統文字樣式名稱，引用前查證（書的查證日期 2026-10）。

import SwiftUI

enum Token {

    // MARK: 顏色（值放在 Assets.xcassets，每色淺色／深色／增加對比各一組）
    enum Colors {
        // 底
        static let groupedBackground = Color("底-群組")   // F2F2F7 / 000000
        static let rowBackground     = Color("底-列")     // FFFFFF / 1C1C1E
        // 字
        static let textPrimary   = Color("文字-主")       // 000000 / FFFFFF
        static let textSecondary = Color("文字-次")       // 6C6C70 / 98989F（系統 secondaryLabel 淺色只有 3.44:1，不用）
        static let link          = Color("強調-可點")     // 8F6200 / F2C14E（網頁版 B98000 淺色只有 3.41:1，不用）
        static let danger        = Color("警示-文字")     // D70015 / FF6961
        // 主要動作（每個畫面只出現一次）
        static let actionFill = Color("動作-底玉米")      // F2C14E
        static let actionInk  = Color("動作-字玉米")      // 2B2000
        // 錄音
        static let recordingFill  = Color("錄音-紅底")    // FF3B30 / FF453A
        static let recordingGlyph = Color("錄音-字圖形")  // 380000（白色在增加對比・深色下只有 2.82:1）
        static let waveform       = Color("強調-可點")
        // 首頁統計方塊
        static let harvestTileInk = Color("方塊-收成字")  // 3A2800，底是 F6CF63→E3A922 漸層
        static let pendingTileInk = Color("方塊-待轉字")  // 0E2206，底是 9CC46A→6E9C3E 漸層（白字只有 2.00:1）
        static let separator      = Color(uiColor: .separator)
    }

    // MARK: 文字（全部是系統文字樣式，跟著動態字級走；不寫死字級）
    enum Fonts {
        static let largeTitle = Font.largeTitle.bold()       // 首頁「米說」
        static let sectionTitle = Font.title3.bold()         // 「今天」「本週」
        static let rowTitle = Font.headline                  // 清單列標題
        static let body = Font.body                          // 文字稿正文
        static let secondary = Font.subheadline              // 列預覽、副標
        static let footnote = Font.footnote                  // 區段下方說明
        static let timer = Font.system(.largeTitle, design: .rounded).monospacedDigit().weight(.light) // 錄音計時
    }

    // MARK: 間距（六個刻度）
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16    // 畫面左右邊距
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        // 靠近文字的間距在畫面裡用 @ScaledMetric(relativeTo:) 包一次，跟著字級放大
    }

    // MARK: 形狀
    enum Shape {
        static let radiusRow: CGFloat = 16      // 分組列表
        static let radiusTile: CGFloat = 20     // 首頁統計方塊
        static let radiusSheet: CGFloat = 28    // 錄音面板上緣
        static let minTap: CGFloat = 44         // 一般點擊範圍底線
        static let primaryTap: CGFloat = 60     // 主要動作（錄音鈕）
        static let stopTap: CGFloat = 80        // 錄音面板停止鈕
    }

    // MARK: 動態（事件命名；每個都有減少動態版，是替換不是關掉）
    enum Motion {
        static func recordPress(_ reduce: Bool) -> Animation {
            reduce ? .easeOut(duration: 0.12) : .spring(duration: 0.25, bounce: 0.1)
        }
        static let recordPressScale: CGFloat = 0.94              // 減少動態時不縮放，改底色加深
        static func sheetRise(_ reduce: Bool) -> Animation {
            reduce ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0)
        }
        static let waveformHz: Double = 20                       // 減少動態時改成固定位置的音量條
        static let recordingPulse: Double = 1.4                  // 秒；減少動態時不脈動
        static func harvestDrop(_ reduce: Bool) -> Animation {
            reduce ? .easeIn(duration: 0.15) : .spring(duration: 0.6, bounce: 0.25)
        }
    }

    // MARK: 觸覺（事件命名；每種事件只對應一種）
    enum Haptics {
        static let recordStart: SensoryFeedback = .start
        static let recordStop: SensoryFeedback = .stop
        static let transcriptReady: SensoryFeedback = .success
        static let failed: SensoryFeedback = .warning
        static let copied: SensoryFeedback = .impact(weight: .light)
    }
}

// MARK: 角色色（不進介面語意層：不當文字色、不當按鈕色）
enum CharacterPalette {
    static let cornKernel = Color(red: 0.95, green: 0.76, blue: 0.31)   // 玉米粒
    static let cornHusk   = Color(red: 0.43, green: 0.61, blue: 0.24)   // 玉米葉
    static let popcorn    = Color(red: 1.00, green: 0.97, blue: 0.88)   // 爆米花
}
