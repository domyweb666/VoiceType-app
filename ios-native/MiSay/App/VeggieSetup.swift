import SwiftUI
import VeggieKit

// 蔬菜家族共用元件（VeggieKit）在米說的那一份設定。
// 只有這個檔知道米說在家族裡的代號、信箱、網址；設定頁各區從這裡拿。

extension VeggieConfig {
    static let misay = VeggieConfig(
        name: "芋音",
        slug: "misay",
        // 分享給朋友時跟著送出。照核心動作卡的一句話任務縮短，米還沒定（App Store 副標定了再換成同一句）
        tagline: "說一段話，得到可以直接貼的乾淨文字",
        // Apple ID 還沒填：填了「在 App Store 給我們評分」那列才出現，分享的字也會換成下載連結
        appStoreID: nil,
        // VeggieKit README 的範例信箱，全家共用一個
        supportEmail: "charlie@domyweb.org",
        // 網頁還沒有：填了「隱私權政策」那列才出現，要跟 App Store Connect 填的同一頁
        privacyURL: nil
    )
}

extension VeggieStyle {
    /// 共用元件照米說的代號畫：可點的字與圖示用深金（跟設定頁其他開關同色）
    static let misay = VeggieStyle(
        textPrimary: Token.Colors.textPrimary,
        textSecondary: Token.Colors.textSecondary,
        textTertiary: Token.Colors.textTertiary,
        accent: Token.Colors.link,
        destructive: Token.Colors.danger,
        canvas: Token.Colors.groupedBackground,
        surface: Token.Colors.rowBackground,
        body: Token.Fonts.body,
        headline: Token.Fonts.rowTitle,
        subheadline: Token.Fonts.secondary,
        footnote: Token.Fonts.footnote,
        rowHeight: Token.Shape.minTap
    )
}
