import SwiftUI

/// 口述統計：口述字數、節省時間、口述速度、總口述時間（2026-11-08 米：像 Typeless 那張）。
/// 放在設定頁最上面；同天先放文字稿頁，米看過改到設定頁。
/// 全部從已存的文字稿算，不另外記資料。
struct DictationStats: Equatable {
    /// 手機打字一分鐘幾個字。注音大約 20～40，取 40：寧可「節省時間」算少，不灌水。
    static let typingCharactersPerMinute: Double = 40

    /// 口語稿的字數（講了多少），空白換行不算。
    let spokenCharacters: Int
    /// 文字稿的字數（拿去用的那份），算「打字要打多久」用這個。
    let writtenCharacters: Int
    let spokenSeconds: Double

    init(transcripts: [Transcript]) {
        spokenCharacters = transcripts.reduce(0) { $0 + Self.countCharacters($1.rawText) }
        writtenCharacters = transcripts.reduce(0) { $0 + Self.countCharacters($1.displayText) }
        spokenSeconds = transcripts.reduce(0) { $0 + max($1.durationSeconds, 0) }
    }

    static func countCharacters(_ text: String) -> Int {
        text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count
    }

    /// 一分鐘講幾個字；錄不到一秒就不算，免得除出一個嚇人的數字。
    var charactersPerMinute: Int {
        guard spokenSeconds >= 1 else {
            return 0
        }
        return Int((Double(spokenCharacters) / (spokenSeconds / 60)).rounded())
    }

    /// 用打的要多久，減掉實際講的時間；講得比打得慢就是 0，不給負數。
    var savedSeconds: Double {
        let typingSeconds = Double(writtenCharacters) / Self.typingCharactersPerMinute * 60
        return max(typingSeconds - spokenSeconds, 0)
    }

    /// 「45 秒」「12 分鐘」「3 小時 5 分」：數字與單位分開，卡片上單位字比較小。
    static func duration(_ seconds: Double) -> (value: String, unit: String) {
        let total = Int(seconds.rounded())
        if total < 60 {
            return ("\(total)", "秒")
        }
        let minutes = total / 60
        if minutes < 60 {
            return ("\(minutes)", "分鐘")
        }
        let rest = minutes % 60
        return rest == 0 ? ("\(minutes / 60)", "小時") : ("\(minutes / 60) 小時 \(rest)", "分")
    }
}

/// 白卡片、兩欄兩列：大數字＋小單位在上，說明在下。
struct DictationStatsCard: View {
    let stats: DictationStats

    var body: some View {
        let saved = DictationStats.duration(stats.savedSeconds)
        let spoken = DictationStats.duration(stats.spokenSeconds)
        Grid(
            alignment: .leading,
            horizontalSpacing: Token.Space.l,
            verticalSpacing: Token.Space.l
        ) {
            GridRow {
                cell(stats.spokenCharacters.formatted(), unit: "字", label: "口述字數")
                cell(saved.value, unit: saved.unit, label: "節省時間")
            }
            GridRow {
                cell("\(stats.charactersPerMinute)", unit: "字／分", label: "平均口述速度")
                cell(spoken.value, unit: spoken.unit, label: "總口述時間")
            }
        }
        .padding(.vertical, Token.Space.s)
    }

    private func cell(_ value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Token.Space.xs) {
                Text(value)
                    .font(Token.Fonts.statValue)
                Text(unit)
                    .font(Token.Fonts.rowTitle)
            }
            .foregroundStyle(Token.Colors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(label)
                .font(Token.Fonts.secondary)
                .foregroundStyle(Token.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
