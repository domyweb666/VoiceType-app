// 由 domy-design/scripts/build-swift.mjs 從 tokens/tokens.json 產生，不要手改。
// Domy Design System 1.1.0
import SwiftUI
import UIKit

public enum DomyTokens {
    public static let version = "1.1.0"

    public enum Space {
        public static let s1: CGFloat = 4
        public static let s2: CGFloat = 8
        public static let s3: CGFloat = 12
        public static let s4: CGFloat = 16
        public static let s5: CGFloat = 20
        public static let s6: CGFloat = 24
        public static let s8: CGFloat = 32
        public static let s12: CGFloat = 48
    }

    public enum Radius {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let pill: CGFloat = 999
    }

    public enum Size {
        public static let touch: CGFloat = 44
        public static let button: CGFloat = 52
        public static let buttonCompact: CGFloat = 36
        public static let iconButton: CGFloat = 44
        public static let row: CGFloat = 52
        public static let field: CGFloat = 48
        public static let screenMargin: CGFloat = 20
        public static let tabBar: CGFloat = 64
        public static let tabBarWidth: CGFloat = 300
        public static let tabBarBottom: CGFloat = 12
        public static let heroButton: CGFloat = 180
        public static let heroRing: CGFloat = 216
        public static let heroRingWidth: CGFloat = 3
        public static let switchWidth: CGFloat = 51
        public static let switchHeight: CGFloat = 31
        public static let pickerHeight: CGFloat = 34
        public static let emptyIcon: CGFloat = 64
        public static let hairline: CGFloat = 1
    }

    public enum Motion {
        public static let pressDuration: Double = 0.12
        public static let pressScale: CGFloat = 0.97
        public static let pressedOpacity: Double = 0.6
        public static let transition: Double = 0.25
    }

    public enum Elevation {
        public static let level1 = DomyShadow(y: 4, radius: 9, opacity: 0.06)
        public static let level2 = DomyShadow(y: 8, radius: 12, opacity: 0.1)
    }

    /// 字級。用 .font(DomyTokens.TypeScale.body.font) 會跟著系統字級縮放。
    public enum TypeScale {
        public static let largeTitle = DomyTypeStyle(size: 34, lineHeight: 41, weight: .bold, textStyle: .largeTitle)
        public static let title1 = DomyTypeStyle(size: 28, lineHeight: 34, weight: .bold, textStyle: .title)
        public static let title2 = DomyTypeStyle(size: 22, lineHeight: 28, weight: .bold, textStyle: .title2)
        public static let title3 = DomyTypeStyle(size: 20, lineHeight: 25, weight: .semibold, textStyle: .title3)
        public static let headline = DomyTypeStyle(size: 17, lineHeight: 22, weight: .semibold, textStyle: .headline)
        public static let body = DomyTypeStyle(size: 17, lineHeight: 26, weight: .regular, textStyle: .body)
        public static let callout = DomyTypeStyle(size: 16, lineHeight: 21, weight: .semibold, textStyle: .callout)
        public static let subheadline = DomyTypeStyle(size: 15, lineHeight: 20, weight: .regular, textStyle: .subheadline)
        public static let footnote = DomyTypeStyle(size: 13, lineHeight: 18, weight: .regular, textStyle: .footnote)
        public static let caption = DomyTypeStyle(size: 12, lineHeight: 16, weight: .medium, textStyle: .caption)
    }

    public enum Neutral {
        public static let surface = Color(domyLight: 0xFFFFFF, domyDark: 0x1C1C1E)
        public static let surfaceMuted = Color(domyLight: 0xEFEBE3, domyDark: 0x2C2C2E)
        public static let separator = Color(domyLight: 0xE5E1D8, domyDark: 0x38383A)
        public static let fieldBorder = Color(domyLight: 0xD8D3C8, domyDark: 0x48484A)
        public static let textPrimary = Color(domyLight: 0x1D1D1F, domyDark: 0xF5F5F7)
        public static let textSecondary = Color(domyLight: 0x66666D, domyDark: 0xA1A1A8)
        public static let textTertiary = Color(domyLight: 0xA1A1A6, domyDark: 0x636366)
        public static let textDisabled = Color(domyLight: 0x8E8E93, domyDark: 0x7C7C80)
        public static let destructive = Color(domyLight: 0xC4372C, domyDark: 0xFF6B5E)
        public static let destructiveSoft = Color(domyLight: 0xFBEDEB, domyDark: 0x3A1E1B)
        public static let shadow = Color(domyLight: 0x191614, domyDark: 0x000000)
    }

    public enum Canvas {
        public static let standard = Color(domyLight: 0xF5F5F7, domyDark: 0x000000)
        public static let warm = Color(domyLight: 0xF7F4EC, domyDark: 0x14130F)
    }
}

public struct DomyShadow: Sendable {
    public let y: CGFloat
    public let radius: CGFloat
    public let opacity: Double
}

public struct DomyTypeStyle: Sendable {
    public let size: CGFloat
    public let lineHeight: CGFloat
    public let weight: Font.Weight
    public let textStyle: Font.TextStyle
    public var font: Font { .system(textStyle).weight(weight) }
    /// 中文行高：配 .lineSpacing(style.lineSpacing) 使用
    public var lineSpacing: CGFloat { max(0, lineHeight - size * 1.2) }
}

/// 一款 App 的產品色。canvas 是畫布色，其餘是五階產品色加壓在上面的字色。
public struct DomyTheme: Sendable {
    public let name: String
    public let canvas: Color
    public let accent: Color
    public let onAccent: Color
    public let strong: Color
    public let soft: Color
    public let tint: Color
    public let bright: Color
    public let onBright: Color
}

public extension DomyTheme {
    /// 金棕
    static let gold = DomyTheme(
        name: "gold",
        canvas: Color(domyLight: 0xF7F4EC, domyDark: 0x14130F),
        accent: Color(domyLight: 0x916B1B, domyDark: 0xD9AE4E),
        onAccent: Color(domyLight: 0xFFFFFF, domyDark: 0x2B2006),
        strong: Color(domyLight: 0x7A5916, domyDark: 0xE6C277),
        soft: Color(domyLight: 0xF1E6CC, domyDark: 0x3A2F17),
        tint: Color(domyLight: 0xFBF7ED, domyDark: 0x211B10),
        bright: Color(domyLight: 0xE9C46A, domyDark: 0xE9C46A),
        onBright: Color(domyLight: 0x2B2006, domyDark: 0x2B2006)
    )
    /// 梅紫
    static let plum = DomyTheme(
        name: "plum",
        canvas: Color(domyLight: 0xF5F5F7, domyDark: 0x000000),
        accent: Color(domyLight: 0x8B5A71, domyDark: 0xD7A3BB),
        onAccent: Color(domyLight: 0xFFFFFF, domyDark: 0x2A1520),
        strong: Color(domyLight: 0x74485D, domyDark: 0xE7C0D1),
        soft: Color(domyLight: 0xF3E6EB, domyDark: 0x3A2530),
        tint: Color(domyLight: 0xFAF4F6, domyDark: 0x1F161A),
        bright: Color(domyLight: 0xD9A7BD, domyDark: 0xD9A7BD),
        onBright: Color(domyLight: 0x2A1520, domyDark: 0x2A1520)
    )
    /// 鼠尾草
    static let sage = DomyTheme(
        name: "sage",
        canvas: Color(domyLight: 0xF5F5F7, domyDark: 0x000000),
        accent: Color(domyLight: 0x4F6B57, domyDark: 0x9DC2A5),
        onAccent: Color(domyLight: 0xFFFFFF, domyDark: 0x12251A),
        strong: Color(domyLight: 0x3F5746, domyDark: 0xBFD9C4),
        soft: Color(domyLight: 0xE3ECE5, domyDark: 0x22322A),
        tint: Color(domyLight: 0xF4F8F5, domyDark: 0x141B17),
        bright: Color(domyLight: 0x9DC2A5, domyDark: 0x9DC2A5),
        onBright: Color(domyLight: 0x12251A, domyDark: 0x12251A)
    )
}

extension Color {
    /// 淺色、深色各一個值，跟著系統外觀切換
    init(domyLight light: UInt32, domyDark dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            UIColor(domyHex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(domyHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
