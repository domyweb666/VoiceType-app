import Foundation

/// 片 J2：一串數字字讀成值（阿拉伯數字、中文數字、混著寫）。讀不出一個確定的值就回 nil。
struct NumberReading {
    private static let digits: [Character: Int] = {
        var table: [Character: Int] = [:]
        for (value, character) in MeaningText.fold("零一二三四五六七八九").enumerated() {
            table[character] = value
        }
        for character in MeaningText.fold("〇") {
            table[character] = 0
        }
        for character in MeaningText.fold("兩") {
            table[character] = 2
        }
        return table
    }()

    private static let units: [Character: Double] = {
        var table: [Character: Double] = [:]
        let sizes: [Double] = [10, 100, 1000, 10000, 100_000_000]
        for (character, size) in zip(MeaningText.fold("十百千萬億"), sizes) {
            table[character] = size
        }
        return table
    }()

    private static let spokenPoints = Set(MeaningText.fold("點"))
    /// 萬以上：前面整段一起乘。
    private static let bigUnit: Double = 10000
    /// 一百二、兩萬五這種省略說法，從百開始才有。
    private static let smallestShortened: Double = 100
    private static let unitStep: Double = 10

    private var total: Double = 0
    private var section: Double = 0
    private var pending: Double?
    private var lastUnit: Double = 0
    private var hasZero = false

    static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    static func isSpokenDigit(_ character: Character) -> Bool {
        digits[character] != nil
    }

    static func isUnit(_ character: Character) -> Bool {
        units[character] != nil
    }

    static func isSpokenPoint(_ character: Character) -> Bool {
        spokenPoints.contains(character)
    }

    static func isNumeric(_ character: Character) -> Bool {
        isDigit(character) || isSpokenDigit(character) || isUnit(character)
    }

    static func value(of run: [Character]) -> Double? {
        let compact = run.filter { $0 != " " && $0 != "," }
        let hasUnit = compact.contains { isUnit($0) }
        return hasUnit ? valueWithUnits(compact) : plainValue(compact)
    }

    /// 約數（兩三、七八十）裡的每個數字；原文有一個對得上就不算不見。
    static func looseValues(of run: [Character]) -> [Double] {
        let spoken = run.compactMap { digits[$0] }.map { Double($0) }
        let pieces = run.split { !isDigit($0) }
        return spoken + pieces.compactMap { Double(String($0)) }
    }

    /// 沒有十百千：320、3.5、二零二六、三點五。只有兩個字（七八、三五）多半是約數，不讀。
    private static func plainValue(_ run: [Character]) -> Double? {
        if run.allSatisfy({ isDigit($0) || $0 == "." }) {
            return Double(String(run))
        }
        let whole = run.prefix { !isSpokenPoint($0) }
        let hasZero = whole.contains { digits[$0] == 0 }
        guard whole.count != 2 || hasZero else {
            return nil
        }
        return spokenValue(run)
    }

    /// 一個一個唸的中文數字，中間可以有「點」。
    private static func spokenValue(_ run: [Character]) -> Double? {
        var text = ""
        for character in run {
            if let digit = digits[character] {
                text += String(digit)
            } else if isSpokenPoint(character) {
                text += "."
            } else {
                return nil
            }
        }
        return Double(text)
    }

    private static func valueWithUnits(_ run: [Character]) -> Double? {
        var reading = NumberReading()
        var index = 0
        while index < run.count {
            let character = run[index]
            if let unit = units[character] {
                guard reading.take(unit: unit) else {
                    return nil
                }
                index += 1
            } else if digits[character] == 0, reading.pending == nil {
                reading.hasZero = true
                index += 1
            } else {
                let end = literalEnd(in: run, from: index)
                guard reading.take(literal: literal(Array(run[index ..< end]))) else {
                    return nil
                }
                index = end
            }
        }
        return reading.finished()
    }

    /// 阿拉伯數字一整串算一個；中文數字一個字算一個，後面可以接「點」幾個字。
    private static func literalEnd(in run: [Character], from start: Int) -> Int {
        var end = start + 1
        if isDigit(run[start]) {
            while end < run.count, isDigit(run[end]) || run[end] == "." {
                end += 1
            }
            return end
        }
        guard end < run.count, isSpokenPoint(run[end]) else {
            return end
        }
        end += 1
        while end < run.count, isSpokenDigit(run[end]) {
            end += 1
        }
        return end
    }

    private static func literal(_ piece: [Character]) -> Double? {
        piece.allSatisfy { isDigit($0) || $0 == "." }
            ? Double(String(piece))
            : spokenValue(piece)
    }

    private mutating func take(literal: Double?) -> Bool {
        guard let literal, pending == nil else {
            return false
        }
        pending = literal
        return true
    }

    private mutating func take(unit: Double) -> Bool {
        guard let count = pending ?? impliedCount(before: unit) else {
            return false
        }
        if unit < Self.bigUnit {
            section += count * unit
        } else {
            total += (section + count) * unit
            section = 0
        }
        pending = nil
        lastUnit = unit
        hasZero = false
        return true
    }

    /// 十五的十前面省略了一；三十萬的萬前面沒有零頭；其他前面沒數字的單位（幾百、上千）不讀。
    private func impliedCount(before unit: Double) -> Double? {
        if unit < Self.smallestShortened, section.isZero {
            return 1
        }
        return unit >= Self.bigUnit && section > 0 ? 0 : nil
    }

    /// 最後剩一個數字：一百二是 120，一百零二是 102。
    private func finished() -> Double {
        guard let pending else {
            return total + section
        }
        let isShortened = lastUnit >= Self.smallestShortened && !hasZero
            && pending < Self.unitStep
        return total + section + (isShortened ? pending * lastUnit / Self.unitStep : pending)
    }
}
