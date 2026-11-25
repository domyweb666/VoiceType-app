@testable import MiSay
import XCTest

/// 片 J2「可能改了意思」：真的少了否定字、數字、名字才標，刪重講與換寫法不標。句子都是自編的。
final class MeaningCheckTests: XCTestCase {
    private let vocabulary = ["林小芳", "Notion", "Claude", "Claude Code", "陳老師"]

    // MARK: 否定字

    func test少了不字有標_位置指到那個字() {
        let raw = "我明天不會去公司所以你不要等我"
        let findings = check(raw, "我明天會去公司，所以你不要等我。").findings

        XCTAssertEqual(findings.map(\.kind), [.negation])
        XCTAssertEqual(findings.first?.offset, 3)
        XCTAssertEqual(findings.first?.before, "我明天")
        XCTAssertEqual(findings.first?.word, "不")
        XCTAssertEqual(findings.first?.after, "會去公司所以你不要等我")
    }

    func test刪重講不標() {
        assertNothing("我跟你說我不會我不會去那個聚會", "我跟你說，我不會去那個聚會。")
        assertNothing("呃我我不我不知道欸就是那個", "我不知道，就是那個。")
        assertNothing("那原因不是那原因不是這個", "那原因不是這個。")
    }

    func test附近有別的否定字_少掉的那個照樣有標() {
        assertKinds("他說不要急不要怕", "他說不要急，要怕。", [.negation])
        assertKinds("他說不要急不要怕", "他說要急，不要怕。", [.negation])
        assertKinds("讓不鹹也沒味的新配方上場", "讓不鹹也味的新配方上場。", [.negation])
    }

    func test換成肯定的字有標_換成另一種否定不標() {
        assertKinds("我不喜歡那個地方", "我很喜歡那個地方。", [.negation])
        assertKinds("別擔心這件事", "擔心這件事。", [.negation])
        assertNothing("這個東西我沒有用過", "這個東西我未曾用過。")
        assertNothing("這個不容易做到", "這個很難做到。")
    }

    func test問句和不算否定的詞不標() {
        assertNothing("你覺得這樣對不對就是你有沒有覺得", "你覺得這樣對嗎？你覺得呢？")
        assertNothing("你喜歡不喜歡這個", "你喜歡這個嗎？")
        assertNothing("不過我覺得還好", "但我覺得還好。")
        assertNothing("這個特別好", "這個非常好。")
        assertNothing("他不得不走", "他必須走。")
        assertNothing("你吃了沒？我買了便當", "你吃了嗎？我買了便當。")
        assertNothing("你吃了沒有", "你吃了嗎？")
    }

    func test整個詞換掉不標() {
        assertNothing("不過便當有點鹹", "但便當有點鹹。")
        assertNothing("這間店特別擠", "這間店非常擠。")
        assertNothing("這是特別的口味", "這是特殊的口味。")
        assertNothing("無論下不下雨都開店", "不論下不下雨都開店。")
        assertNothing("遲到沒關係啦我等你", "遲到不要緊，我等你。")
        assertNothing("差不多二十個人", "大約 20 個人。")
        assertNothing("未來要搬家", "將來要搬家。")
        assertNothing("他不得不走", "他得走。")
        assertNothing("不過不過便當有點鹹", "不過便當有點鹹。")
    }

    func test詞的其他字還在_只有否定字不見_照樣有標() {
        assertKinds("他遲到沒關係", "他遲到有關係。", [.negation])
        assertKinds("帳單的數字沒錯", "帳單的數字有錯。", [.negation])
        assertKinds("店長不管倉庫", "店長管倉庫。", [.negation])
        assertKinds("下雨我就不過去", "下雨我就過去。", [.negation])
        assertKinds("隔壁的姊姊未婚", "隔壁的姊姊已婚。", [.negation])
        assertKinds("排了半天隊結果到了沒想到沒開", "排了半天隊，結果到了想到沒開。", [.negation])
        assertKinds("流量無限", "流量有限。", [.negation])
        assertKinds("他不得不走", "他不得走。", [.negation])
    }

    func test口語稿簡體文字稿繁體() {
        assertNothing("这个东西我没有用过别担心", "這個東西我沒有用過，別擔心。")
        assertKinds("我明天不会去公司", "我明天會去公司。", [.negation])
        assertKinds("这个东西我没有用过", "這個東西我有用過。", [.negation])
        XCTAssertEqual(check("这个东西我没有用过", "這個東西我有用過。").findings.first?.word, "没")
    }

    // MARK: 數字

    func test數字換寫法不標() {
        let pairs = [
            ("大概三百二十塊", "大概 320 塊。"),
            ("大概有百分之十五的人", "大概有 15% 的人。"),
            ("我買了兩萬五的相機", "我買了 25,000 的相機。"),
            ("花了一百二", "花了 120。"),
            ("一千零五十元", "1050 元"),
            ("人口一億三千萬", "人口 1.3 億。"),
            ("兩百五十萬", "250 萬"),
            ("二零二六年的時候我十八歲", "2026 年的時候，我 18 歲。"),
            ("下午三點五十分開會", "下午 3:50 開會。"),
            ("十二點五公分", "12.5 公分"),
            ("百分之百", "100%"),
            ("三分之一的人", "1/3 的人"),
            ("三四個人", "三、四個人。"),
            ("十分鐘", "10 分鐘。"),
            ("我买了两千本书", "我買了 2,000 本書。"),
        ]
        for (raw, polished) in pairs {
            assertNothing(raw, polished)
        }
    }

    func test數字變了有標() {
        assertKinds("大概三百二十塊", "大概 350 塊。", [.number])
        assertKinds("大概有百分之十五的人", "大概有 50% 的人。", [.number])
        assertKinds("一千零五十元", "1500 元", [.number])
        assertKinds("我買了一個相機", "我買了兩個相機。", [.number])
        assertKinds(
            "第一天走三十公里第二天走三十公里",
            "第一天走 30 公里，第二天走 50 公里。",
            [.number]
        )
        XCTAssertEqual(check("大概三百二十塊", "大概 350 塊。").findings.first?.word, "三百二十")
        XCTAssertEqual(check("大概三百二十塊", "大概 350 塊。").findings.first?.offset, 2)
    }

    func test單獨的一_約數_成語_條列編號不標() {
        assertNothing("我買了一個相機", "我買了相機。")
        assertNothing("兩三天就好", "幾天就好。")
        assertNothing("這個十分好", "這個非常好。")
        assertNothing("萬一他先到", "如果他先到。")
        assertNothing("然後一個是時間然後一個是錢", "1. 時間\n2. 錢")
        assertKinds("第二個重點是錢", "重點是錢。", [.number])
    }

    // MARK: 名字

    func test名字少了有標() {
        assertKinds("我昨天跟林小芳講了很久", "我昨天跟朋友講了很久。", [.name])
        assertKinds("我用claude code寫程式", "我用 AI 寫程式。", [.name])
        XCTAssertEqual(
            check("我用claude code寫程式", "我用 AI 寫程式。").findings.first?.word,
            "claude code"
        )
        assertKinds("陈老师说可以", "他說可以。", [.name])
    }

    func test名字只差大小寫簡繁空白_或附近還在_不標() {
        assertNothing("我用 notion 記東西", "我用 Notion 記東西。")
        assertNothing("我用claude code寫程式", "我用 Claude Code 寫程式。")
        assertNothing("陈老师说可以", "陳老師說可以。")
        assertNothing("林小芳呢就是林小芳她說可以", "林小芳說可以。")
    }

    // MARK: 其他

    func test沒改就沒有_空的不比() {
        assertNothing("我不會去，大概三百塊。", "我不會去，大概三百塊。")
        assertNothing("", "我不會去。")
        assertNothing("我不會去", "")
        assertKinds("我不會去", "。", [.negation])
    }

    func test長句只帶前後一小段_換行變空白() {
        let lead = String(repeating: "前", count: 40)
        let tail = String(repeating: "後", count: 40)
        let raw = lead + "\n我不去\n" + tail
        let finding = check(raw, lead + "我去" + tail).findings.first

        XCTAssertEqual(finding?.offset, 42)
        XCTAssertEqual(finding?.before, "…" + String(repeating: "前", count: 12) + " 我")
        XCTAssertEqual(finding?.after, "去 " + String(repeating: "後", count: 12) + "…")
    }

    func test沒找到或沒比就不出現() {
        XCTAssertFalse(SourceSheetMeaning.shows(nil))
        XCTAssertFalse(SourceSheetMeaning.shows([]))
        XCTAssertTrue(SourceSheetMeaning.shows(check("我不會去", "我會去。").findings))
    }

    private func check(_ raw: String, _ polished: String) -> MeaningCheck {
        MeaningCheck(raw: raw, polished: polished, vocabulary: vocabulary)
    }

    private func assertNothing(
        _ raw: String,
        _ polished: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertKinds(raw, polished, [], file: file, line: line)
    }

    private func assertKinds(
        _ raw: String,
        _ polished: String,
        _ kinds: [MeaningCheck.Kind],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = check(raw, polished).findings.map(\.kind)
        XCTAssertEqual(found, kinds, "\(raw) → \(polished)", file: file, line: line)
    }
}
