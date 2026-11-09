import SwiftUI

/// 米說 設計代號（2026-11-07，v2.0 統一風格）
///
/// 規則：畫面程式只准用這裡的語意代號（Token.*）。色碼、字級、間距、動畫數字
/// 只准出現在這個檔案與顏色資源裡。提交前自動檢查會擋（見 使用規則.md 最後一節）。
///
/// 數字來源：v2 的顏色、圓角、按鈕尺寸抄自 Design 畫布「米說 全畫面統一設計」的風格總表
/// （https://claude.ai/artifact/S6UsLgtxX9FkFgkHSJXrwV ），再依 對比檢查表.md 跑過；
/// 間距沿用 03-線框；動態、觸覺沿用 04-手感/參數表.md。色碼全列在 contrast-pairs.json。
///
/// `.uiux/05-設計代號/Tokens.swift` 是源頭；這份是逐字抄本，兩邊要一模一樣。
/// v2.0（2026-11-07）：米定統一風格。底色改爆米花、字色跟著調、加凹槽與分隔線、
/// 主要按鈕 56 高膠囊、錄音鈕快門式（金環＋圓盤＋實心麥克風）、計時 56；
/// 實作時補了圖示圓、停止鈕圖形、狀態條陰影、玉米插圖尺寸、按下與停用的透明度。
/// v1.1（2026-10-31）：只改排版讓 SwiftFormat／SwiftLint 過；加 `Shape.recordTap` 220。
///
/// ⚠️ 會過時：@ScaledMetric、.sensoryFeedback、彈簧的 duration/bounce 寫法、
/// 系統文字樣式名稱，引用前查證（書的查證日期 2026-10）。需要 iOS 17。
enum Token {
    /// 顏色（值放在 Assets.xcassets，每色淺色／深色／增加對比各一組；色碼見 contrast-pairs.json）
    enum Colors {
        /// 底
        static let groupedBackground = Color("底-群組") // 爆米花底 F7F4EC / 141210
        static let rowBackground = Color("底-列") // 卡片、錄音面板底 FFFFFF / 1F1C18
        /// 凹槽：搜尋框、分段控制的軌道、面板裡的預覽卡與圖示圓 F2EEE4 / 2A2621
        static let sunkenBackground = Color("底-凹槽")
        static let separator = Color("分隔線") // E9E4D8 / 332E27（不再用系統 separator）
        /// 字
        static let textPrimary = Color("文字-主") // 1C1A16 / F4F0E8
        /// 6B665C / A49E93（白卡 5.7:1、爆米花底 5.2:1；系統 secondaryLabel 淺色只有 3.44:1，不用）
        static let textSecondary = Color("文字-次")
        /// 金色。所有能按的字、開關、分段選中、工具列圖示都用它 8F6200 / F2C14E
        static let link = Color("強調-可點")
        static let danger = Color("警示-文字") // D70015 / FF6961，只給刪除與失敗
        /// 主要動作（每個畫面只出現一次）
        static let actionFill = Color("動作-底玉米") // F2C14E
        static let actionInk = Color("動作-字玉米") // 2B2000
        /// 錄音鈕外圈那一環，裝飾用，不入對比表 D9A62E 55% / F2C14E 45%
        static let actionRing = Color("動作-外環")
        /// 錄音鈕圓盤上緣那道亮邊的底色；透明度在 `Elevation`
        static let highlight = Color.white
        /// 陰影的底色；透明度在 `Elevation`
        static let shadow = Color.black
        /// 錄音
        static let recordingFill = Color("錄音-紅底") // FF3B30 / FF453A
        /// 380000（白色在增加對比・深色下只有 2.82:1）
        static let recordingGlyph = Color("錄音-字圖形")
        static let waveform = Color("強調-可點")
        /// 穀倉方塊（第二批才做）：3A2800，底是 F6CF63→E3A922 漸層
        static let harvestTileInk = Color("方塊-收成字")
        /// 0E2206，底是 9CC46A→6E9C3E 漸層（白字只有 2.00:1）
        static let pendingTileInk = Color("方塊-待轉字")
    }

    /// 文字（全部是系統文字樣式，跟著動態字級走；不寫死字級）
    enum Fonts {
        static let largeTitle = Font.largeTitle.bold() // 「文字稿」「設定」「待轉錄」大標
        static let statValue = Font.title.bold() // 文字稿頁統計卡的大數字（11/08）
        static let sectionTitle = Font.title3.bold() // 「今天」「本週」、面板的「好了，已經複製」
        static let rowTitle = Font.headline // 清單列標題、首頁提示第一行、主要按鈕的字
        static let body = Font.body // 文字稿正文、列預覽
        static let secondary = Font.subheadline // 列副標、說明第二行、狀態條
        static let footnote = Font.footnote // 區段標題與下方說明、日期
        static let icon = Font.title2 // 圖示圓裡的圖示、工具列三顆、完成那個勾
        /// 錄音計時 56：畫面用 @ScaledMetric(relativeTo: .largeTitle) 包 `timerSize` 再丟進 `timer(_:)`
        static let timerSize: CGFloat = 56
        static func timer(_ size: CGFloat) -> Font {
            Font.system(size: size, weight: .light, design: .rounded).monospacedDigit()
        }
    }

    /// 間距（六個刻度）。靠近文字的間距在畫面裡用 @ScaledMetric(relativeTo:) 包一次，跟著字級放大
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16 // 畫面左右邊距、卡片內距、分隔線左縮
        static let xl: CGFloat = 24 // 面板左右內距
        static let xxl: CGFloat = 32
        static let lineSpacing: CGFloat = 8 // 文字稿正文行距（行高約 1.65）
    }

    /// 形狀。按鈕一律 Capsule()，沒有數字
    enum Shape {
        static let radiusRow: CGFloat = 16 // 卡片、狀態條、分組列表
        static let radiusField: CGFloat = 12 // 搜尋框、分段控制的軌道
        static let radiusTile: CGFloat = 20 // 穀倉方塊
        static let radiusSheet: CGFloat = 28 // 錄音面板上緣
        static let radiusStopGlyph: CGFloat = 6 // 停止鈕中間那個方形的角
        static let minTap: CGFloat = 44 // 一般點擊範圍底線、文字鈕高度
        static let primaryTap: CGFloat = 56 // 主要按鈕高度，整寬膠囊（v1.1 是 60）
        static let iconCircle: CGFloat = 56 // 面板頂上的圖示圓
        static let stopTap: CGFloat = 80 // 錄音面板停止鈕
        static let stopGlyph: CGFloat = 28 // 停止鈕中間的方形
        static let recordTap: CGFloat = 220 // 首頁錄音鈕點擊範圍（SE 線框是 180；怎麼縮未定）
        static let recordDisc: CGFloat = 184 // 快門式：裡面那顆玉米黃圓盤
        static let recordRing: CGFloat = 3 // 快門式：外圈金環線寬
        static let recordGlyph: CGFloat = 76 // 快門式：中間實心麥克風（11/08 換玉米圖 120，11/09 米換回來）
        static let cornWidth: CGFloat = 88 // 空清單那根玉米
        static let cornHeight: CGFloat = 112
    }

    /// 厚度與陰影：錄音鈕圓盤的上亮下暗用一圈從亮到暗的描邊，不用漸層底
    enum Elevation {
        static let recordHighlightOpacity: Double = 0.4 // highlight 色，貼上緣
        static let recordRimOpacity: Double = 0.16 // actionInk，貼下緣
        static let recordRimWidth: CGFloat = 3 // 那一圈描邊的粗細
        static let recordShadowOpacity: Double = 0.14 // 淺色：黑 14%
        static let recordShadowOpacityDark: Double = 0.45 // 深色：黑 45%
        static let recordShadowRadius: CGFloat = 12
        static let recordShadowY: CGFloat = 10
        static let stripShadowOpacity: Double = 0.1 // 浮在清單上的狀態條（已刪除・復原）
        static let stripShadowRadius: CGFloat = 10
        static let stripShadowY: CGFloat = 6
    }

    /// 動態（事件命名；每個都有減少動態版，是替換不是關掉）
    enum Motion {
        static func recordPress(_ reduce: Bool) -> Animation {
            reduce ? .easeOut(duration: 0.12) : .spring(duration: 0.25, bounce: 0.1)
        }

        static let recordPressScale: CGFloat = 0.94 // 減少動態時不縮放，改底色加深
        static func sheetRise(_ reduce: Bool) -> Animation {
            reduce ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0)
        }

        static let waveformHz: Double = 20 // 減少動態時改成固定位置的音量條
        static let recordingPulse: Double = 1.4 // 秒；減少動態時不脈動
        static func harvestDrop(_ reduce: Bool) -> Animation {
            reduce ? .easeIn(duration: 0.15) : .spring(duration: 0.6, bounce: 0.25)
        }

        static let pressedOpacity: Double = 0.7 // 膠囊與文字鈕按下去變淡
        static let disabledOpacity: Double = 0.4 // 停用的鈕
        /// 按鈕樣式共用：停用最淡，按下次之，平常不透明
        static func buttonOpacity(isEnabled: Bool, isPressed: Bool) -> Double {
            if !isEnabled {
                return disabledOpacity
            }
            return isPressed ? pressedOpacity : 1
        }
    }

    /// 觸覺（事件命名；每種事件只對應一種）
    enum Haptics {
        static let recordStart: SensoryFeedback = .start
        static let recordStop: SensoryFeedback = .stop
        static let transcriptReady: SensoryFeedback = .success
        static let failed: SensoryFeedback = .warning
        static let copied: SensoryFeedback = .impact(weight: .light)
    }

    /// 文字稿編輯框（2026-11-09 邊打邊變樣）是 UIKit 的 UITextView，要 UIKit 的顏色與字型。
    /// 顏色指向同一組顏色資源，深色、增加對比照樣跟著換；字型每次現拿，跟著系統字級走。
    enum Editor {
        static let textPrimary = UIColor(named: "文字-主") ?? .label
        static let textSecondary = UIColor(named: "文字-次") ?? .secondaryLabel // Markdown 記號
        static let cursor = UIColor(named: "強調-可點") ?? .tintColor
        static var body: UIFont {
            UIFont.preferredFont(forTextStyle: .body)
        }

        static var heading: UIFont { // `## ` 那行
            bold(UIFont.preferredFont(forTextStyle: .title2))
        }

        static var marker: UIFont { // 標題前面的 `## `，縮小
            UIFont.preferredFont(forTextStyle: .footnote)
        }

        static func bold(_ font: UIFont) -> UIFont {
            guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) else {
                return font
            }
            return UIFont(descriptor: descriptor, size: 0)
        }
    }
}

/// 角色色（不進介面語意層：不當文字色、不當按鈕色）。玉米插圖只在文字稿空清單與收成那一刻
enum CharacterPalette {
    static let cornKernel = Color(red: 0.95, green: 0.76, blue: 0.31) // 玉米粒
    static let cornKernelShade = Color(red: 0.85, green: 0.65, blue: 0.18) // 玉米粒的暗面
    static let cornHusk = Color(red: 0.43, green: 0.61, blue: 0.24) // 玉米葉
    static let popcorn = Color(red: 1.00, green: 0.97, blue: 0.88) // 爆米花
}
