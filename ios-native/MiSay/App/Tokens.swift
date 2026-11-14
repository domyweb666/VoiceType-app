import SwiftUI

/// 米說 設計代號（2026-11-14，v3.0 domy-design）
///
/// 規則：畫面程式只准用這裡的語意代號（Token.*）。色碼、字級、間距、動畫數字
/// 只准出現在這個檔案、`DomyTokens.swift` 與顏色資源裡。提交前自動檢查會擋（見 使用規則.md 最後一節）。
///
/// 數字來源：多米所有 App 共用的 domy-design 1.1.0（金棕 Theme）。字級、間距、圓角、尺寸、
/// 陰影、按下的回饋直接讀 `DomyTokens`（從 domy-design 複製來的，不要手改）；顏色放在顏色資源，
/// 淺深兩組抄自 domy 的 tokens.json，增加對比那組是米說自己加的（domy 沒有）。
/// 色碼與對比全列在 contrast-pairs.json、對比檢查表.md。
///
/// `.uiux/05-設計代號/Tokens.swift` 是源頭；這份是逐字抄本，兩邊要一模一樣。
/// v3.0（2026-11-14）：米說「參考 domy-design 重新設計全部 UI」。主要按鈕從玉米黃改金棕底白字，
/// 玉米黃只留給錄音大鈕；能按的字改深金（金棕在爆米花底上只有 4.42:1）；錄音中從紅改金棕；
/// 卡片圓角 16 → 20、正文行高照 domy；錄音鈕拿掉上亮下暗那圈，外環改淡金。分頁列照舊用系統的。
/// v2.0（2026-11-07）：統一風格，爆米花底、快門式錄音鈕。v1.1（2026-10-31）：排版。
///
/// ⚠️ 會過時：@ScaledMetric、.sensoryFeedback、彈簧的 duration/bounce 寫法、
/// 系統文字樣式名稱，引用前查證（書的查證日期 2026-10）。需要 iOS 17。
enum Token {
    /// 顏色（值放在 Assets.xcassets，每色淺色／深色／增加對比各一組；色碼見 contrast-pairs.json）
    enum Colors {
        /// 底
        static let groupedBackground = Color("底-群組") // domy canvas.warm F7F4EC / 14130F
        static let rowBackground = Color("底-列") // domy surface：卡片、錄音面板底
        /// domy surfaceMuted：首頁統計那行、面板裡的預覽卡 EFEBE3 / 2C2C2E
        static let sunkenBackground = Color("底-凹槽")
        static let separator = Color("分隔線") // domy separator
        /// 字
        static let textPrimary = Color("文字-主") // 1D1D1F / F5F5F7
        static let textSecondary = Color("文字-次") // 66666D / A1A1A8
        /// domy textTertiary：列右邊的箭頭，裝飾用，不當字
        static let textTertiary = Color("文字-三")
        /// domy strong。所有能按的字、工具列、開關、返回鈕 7A5916 / E6C277
        static let link = Color("強調-深")
        /// domy accent。只當填色與圖示：主要按鈕底、停止鈕、波形、錄音中外環 916B1B / D9AE4E
        static let accent = Color("強調-可點")
        /// 壓在 `accent` 上的字與圖形 FFFFFF / 2B2006
        static let onAccent = Color("強調-上字")
        /// domy soft：潤飾方式膠囊、錄音中膠囊、圖示圓的底、錄音鈕待機外環 F1E6CC / 3A2F17
        static let accentSoft = Color("強調-淡")
        /// domy tint：統計卡的底 FBF7ED / 211B10
        static let accentTint = Color("強調-底")
        static let danger = Color("警示-文字") // domy destructive C4372C / FF6B5E，只給刪除與失敗
        static let dangerSoft = Color("警示-淡") // 刪除鈕的淡紅底
        /// domy bright：錄音大鈕的圓盤（整個 App 只有這裡用）E9C46A
        static let actionFill = Color("動作-底玉米")
        static let actionInk = Color("動作-字玉米") // domy onBright 2B2006
        /// 錄音大鈕待機的外環，跟 `accentSoft` 同色；裝飾，不入對比表
        static let actionRing = Color("動作-外環")
        /// 陰影的底色；透明度在 `Elevation`
        static let shadow = DomyTokens.Neutral.shadow
        /// 錄音中（domy：進行中用產品色實心，不用紅）
        static let recordingFill = Color("強調-可點")
        static let recordingGlyph = Color("強調-上字")
        static let waveform = Color("強調-可點")
        /// 穀倉方塊（第二批才做）：3A2800，底是 F6CF63→E3A922 漸層
        static let harvestTileInk = Color("方塊-收成字")
        /// 0E2206，底是 9CC46A→6E9C3E 漸層（白字只有 2.00:1）
        static let pendingTileInk = Color("方塊-待轉字")
    }

    /// 文字（domy 的字級，全部是系統文字樣式，跟著動態字級走；不寫死字級）
    enum Fonts {
        static let largeTitle = DomyTokens.TypeScale.largeTitle.font // 「文字稿」「設定」大標
        static let statValue = DomyTokens.TypeScale.title1.font // 統計卡的大數字
        static let sectionTitle = DomyTokens.TypeScale.title3.font // 「今天」「本週」、首頁提示第一行
        static let rowTitle = DomyTokens.TypeScale.headline.font // 列標題、主要按鈕與文字鈕的字
        static let body = DomyTokens.TypeScale.body.font // 文字稿正文、列預覽
        static let callout = DomyTokens.TypeScale.callout.font // 膠囊裡的字（潤飾方式、錄音中）
        static let secondary = DomyTokens.TypeScale.subheadline.font // 說明第二行、狀態條
        static let footnote = DomyTokens.TypeScale.footnote.font // 列上面的日期、區段下方說明
        static let icon = Font.title2 // 圖示圓裡的圖示、工具列、完成那個勾
        /// 錄音計時 48（domy 錄音畫面）：畫面用 @ScaledMetric(relativeTo: .largeTitle) 包
        /// `timerSize` 再丟進 `timer(_:)`
        static let timerSize: CGFloat = 48
        static func timer(_ size: CGFloat) -> Font {
            Font.system(size: size, weight: .bold).monospacedDigit()
        }
    }

    /// 間距（domy 的刻度）。靠近文字的間距在畫面裡用 @ScaledMetric(relativeTo:) 包一次，跟著字級放大
    enum Space {
        static let xs = DomyTokens.Space.s1 // 4
        static let s = DomyTokens.Space.s2 // 8
        static let m = DomyTokens.Space.s3 // 12
        static let l = DomyTokens.Space.s4 // 16：卡片內距、分隔線左縮
        static let screen = DomyTokens.Size.screenMargin // 20：畫面左右邊距、統計卡內距
        static let xl = DomyTokens.Space.s6 // 24：面板左右內距
        static let xxl = DomyTokens.Space.s8 // 32
        static let lineSpacing = DomyTokens.TypeScale.body.lineSpacing // 正文行高 26
    }

    /// 形狀。按鈕一律 Capsule()，沒有數字
    enum Shape {
        static let radiusRow = DomyTokens.Radius.xl // 20：卡片、狀態條、統計卡
        static let radiusField = DomyTokens.Radius.md // 12：首頁統計那行、輸入框
        static let radiusTile = DomyTokens.Radius.xl // 穀倉方塊
        static let radiusSheet = DomyTokens.Radius.xxl // 24：錄音面板上緣
        static let radiusStopGlyph = DomyTokens.Radius.sm // 停止鈕中間那個方形的角
        static let hairline = DomyTokens.Size.hairline // 統計卡的細框
        static let minTap = DomyTokens.Size.touch // 44：一般點擊範圍底線、文字鈕高度
        static let primaryTap = DomyTokens.Size.button // 52：主要按鈕高度，整寬膠囊
        static let pickerHeight = DomyTokens.Size.pickerHeight // 34：潤飾方式膠囊
        static let iconCircle = DomyTokens.Size.emptyIcon // 64：面板頂上的圖示圓
        static let stopTap: CGFloat = 80 // 錄音面板停止鈕（米說自己的，domy 沒有）
        static let stopGlyph: CGFloat = 28 // 停止鈕中間的方形
        static let recordTap = DomyTokens.Size.heroRing // 216：錄音大鈕連外環
        static let recordDisc = DomyTokens.Size.heroButton // 180：裡面那顆玉米黃圓盤
        static let recordRing = DomyTokens.Size.heroRingWidth // 3：外環線寬
        static let recordGlyph: CGFloat = 64 // 圓盤中間的麥克風（domy 錄音畫面）
        static let cornWidth: CGFloat = 88 // 空清單那根玉米
        static let cornHeight: CGFloat = 112
    }

    /// 陰影：domy 兩級。錄音大鈕與浮在清單上的狀態條用第 2 級，導覽列的白圓鈕用第 1 級
    enum Elevation {
        static let recordShadowOpacity = DomyTokens.Elevation.level2.opacity
        static let recordShadowRadius = DomyTokens.Elevation.level2.radius
        static let recordShadowY = DomyTokens.Elevation.level2.y
        static let stripShadowOpacity = DomyTokens.Elevation.level2.opacity
        static let stripShadowRadius = DomyTokens.Elevation.level2.radius
        static let stripShadowY = DomyTokens.Elevation.level2.y
    }

    /// 動態（事件命名；每個都有減少動態版，是替換不是關掉）
    enum Motion {
        static func recordPress(_ reduce: Bool) -> Animation {
            reduce
                ? .easeOut(duration: DomyTokens.Motion.pressDuration)
                : .spring(duration: DomyTokens.Motion.transition, bounce: 0.1)
        }

        static let recordPressScale = DomyTokens.Motion.pressScale // 減少動態時不縮放，改變淡
        static func sheetRise(_ reduce: Bool) -> Animation {
            reduce ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0)
        }

        static let waveformHz: Double = 20 // 減少動態時改成固定位置的音量條
        static let recordingPulse: Double = 1.4 // 秒；減少動態時不脈動
        static func harvestDrop(_ reduce: Bool) -> Animation {
            reduce ? .easeIn(duration: 0.15) : .spring(duration: 0.6, bounce: 0.25)
        }

        static let pressedOpacity = DomyTokens.Motion.pressedOpacity // 膠囊與文字鈕按下去變淡
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
}

/// 角色色（不進介面語意層：不當文字色、不當按鈕色）。玉米插圖只在文字稿空清單與收成那一刻
enum CharacterPalette {
    static let cornKernel = Color(red: 0.95, green: 0.76, blue: 0.31) // 玉米粒
    static let cornKernelShade = Color(red: 0.85, green: 0.65, blue: 0.18) // 玉米粒的暗面
    static let cornHusk = Color(red: 0.43, green: 0.61, blue: 0.24) // 玉米葉
    static let popcorn = Color(red: 1.00, green: 0.97, blue: 0.88) // 爆米花
}
