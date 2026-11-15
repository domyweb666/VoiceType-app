import Foundation

/// 口語稿的一段（約 5 分鐘，`WAVSegmenter` 切的）在錄音裡從第幾秒到第幾秒、那段轉出來幾個字。
/// 2026-11-15 米：聽原音時要標出正在講哪句、重點的範圍太模糊。轉錄不給每句話的時間，
/// 以前拿整篇字數比例估，誤差幾十秒；改成在每一段裡面估，誤差小很多。
struct TimelineSpan: Codable, Hashable {
    let startSeconds: Double
    let endSeconds: Double
    let characterCount: Int
}

/// 口語稿的每一句大約在錄音的第幾秒（純函式，CI 測得到）。
enum SpokenTimeline {
    struct Sentence: Equatable {
        let index: Int
        let start: Double
        let end: Double
        let text: String
    }

    /// 畫面上的一列：幾句接在一起，讀起來是一段話，不是一句一列。
    struct Block: Equatable, Identifiable {
        let id: Int
        let sentences: [Sentence]

        var start: Double {
            sentences.first?.start ?? 0
        }
    }

    /// 錄音中標的一個重點：按下去那一句加上前一句（人通常是講完才按）。
    struct Passage: Equatable, Identifiable {
        let id: Int
        let markSeconds: Double
        let start: Double
        let text: String
        let sentenceIndexes: [Int]
    }

    static let hardEnds: Set<Character> = ["。", "！", "？", "!", "?", "\n"]
    static let softEnds: Set<Character> = ["，", "、", "；", ",", ";"]
    /// 一句超過這麼長還沒遇到句號，就在下一個逗號斷開，標出來的範圍才不會一大片。
    static let softBreakLength = 30
    /// 一列大約幾個字。
    static let blockLength = 120

    /// 進度檔的段與每段的字 → 時間對照表。少一段的字就不給（對不上比沒有還糟）。
    static func spans(
        segments: [WAVSegmenter.Segment],
        texts: [Int: String],
        framesPerSecond: Int = WAVFileWriter.sampleRate
    ) -> [TimelineSpan]? {
        guard !segments.isEmpty, framesPerSecond > 0 else {
            return nil
        }
        var spans: [TimelineSpan] = []
        for (index, segment) in segments.enumerated() {
            guard let text = texts[index] else {
                return nil
            }
            spans.append(TimelineSpan(
                startSeconds: Double(segment.startFrame) / Double(framesPerSecond),
                endSeconds: Double(segment.endFrame) / Double(framesPerSecond),
                characterCount: text.count
            ))
        }
        return spans
    }

    /// 這篇有沒有對得上的時間對照表：字數加起來要等於口語稿的字數。
    static func isPrecise(_ transcript: Transcript) -> Bool {
        guard let timeline = transcript.timeline, !timeline.isEmpty else {
            return false
        }
        return timeline.reduce(0) { $0 + $1.characterCount } == transcript.rawText.count
    }

    /// 估位置用的對照表。舊的篇沒有，就當整篇是一段（跟以前一樣照整篇字數比例）。
    static func spans(of transcript: Transcript) -> [TimelineSpan] {
        if isPrecise(transcript), let timeline = transcript.timeline {
            return timeline
        }
        let whole = TimelineSpan(
            startSeconds: 0,
            endSeconds: transcript.durationSeconds,
            characterCount: transcript.rawText.count
        )
        return [whole]
    }

    /// 口語稿第幾個字大約在第幾秒：找到它在哪一段，在那一段裡照字數比例。
    static func seconds(ofCharacter offset: Int, in spans: [TimelineSpan]) -> Double {
        var passed = 0
        for span in spans where span.characterCount > 0 {
            if offset < passed + span.characterCount {
                let ratio = Double(offset - passed) / Double(span.characterCount)
                return span.startSeconds + ratio * (span.endSeconds - span.startSeconds)
            }
            passed += span.characterCount
        }
        return spans.last?.endSeconds ?? 0
    }

    /// 口語稿切成一句一句，每句帶大約的起訖秒數。
    static func sentences(of transcript: Transcript) -> [Sentence] {
        let characters = Array(transcript.rawText)
        let timeline = spans(of: transcript)
        var sentences: [Sentence] = []
        var start = 0
        for (offset, character) in characters.enumerated() {
            let isLast = offset == characters.count - 1
            let isSoftBreak = softEnds.contains(character) && offset - start + 1 >= softBreakLength
            guard hardEnds.contains(character) || isSoftBreak || isLast else {
                continue
            }
            let text = String(characters[start ... offset])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                sentences.append(Sentence(
                    index: sentences.count,
                    start: seconds(ofCharacter: start, in: timeline),
                    end: seconds(ofCharacter: offset + 1, in: timeline),
                    text: text
                ))
            }
            start = offset + 1
        }
        return sentences
    }

    /// 幾句湊成一列，湊到大約 `blockLength` 個字就換下一列。
    static func blocks(_ sentences: [Sentence]) -> [Block] {
        var blocks: [Block] = []
        var current: [Sentence] = []
        var length = 0
        for sentence in sentences {
            current.append(sentence)
            length += sentence.text.count
            if length >= blockLength {
                blocks.append(Block(id: blocks.count, sentences: current))
                current = []
                length = 0
            }
        }
        if !current.isEmpty {
            blocks.append(Block(id: blocks.count, sentences: current))
        }
        return blocks
    }

    /// 播到這個秒數是哪一句：開始時間不超過它的最後一句。
    static func sentence(at seconds: Double, in sentences: [Sentence]) -> Sentence? {
        sentences.last { $0.start <= seconds } ?? sentences.first
    }

    /// 每個重點對到哪兩句。
    static func passages(marks: [Double], in sentences: [Sentence]) -> [Passage] {
        marks.enumerated().compactMap { order, mark in
            guard let hit = sentence(at: mark, in: sentences) else {
                return nil
            }
            let picked = Array(sentences[max(0, hit.index - 1) ... hit.index])
            return Passage(
                id: order,
                markSeconds: mark,
                start: picked.first?.start ?? hit.start,
                text: picked.map(\.text).joined(),
                sentenceIndexes: picked.map(\.index)
            )
        }
    }
}
