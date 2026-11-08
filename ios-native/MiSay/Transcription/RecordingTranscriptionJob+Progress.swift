import Foundation

/// 進度檔的內容（拆檔：主檔型別超過 200 行）。存取與加密在主檔的 load／saveProgress。
extension RecordingTranscriptionJob {
    /// 進度檔：哪幾段已經有口語稿，以及這段錄音存進歷史時用哪個 id。放在錄音檔旁邊，錄音刪掉時一起刪。
    /// id 先定好：口語稿存好但錄音刪不掉時，下一輪存回同一篇，不會多一篇重複的。
    /// 每段的起訖與切法版本一起記（S2-1）：舊版照 10 分鐘切的進度檔沒有這兩欄，對不上就從頭轉，
    /// 不拿舊段的字接新段；id 照舊沿用，不會多一篇。
    struct Progress: Codable, Equatable {
        static let currentPlanVersion = 2

        var segmentTexts: [Int: String] = [:]
        var transcriptID = UUID()
        var planVersion: Int?
        var segments: [WAVSegmenter.Segment]?
        /// 重送一次字數還是少的段（從 0 數，S2-2）。
        var suspectSegments: Set<Int> = []
        /// 錄音中先潤飾好的塊（S4-1）：送去潤飾的那塊口語稿與回來的文字稿，一一對應。
        /// 停止後口語稿的那幾塊還一模一樣，才沿用；對不上的從那塊起重做。
        var polishedSources: [String] = []
        var polishedDrafts: [String] = []
        /// 先潤飾那幾塊用的模型與潤飾方式：停止時設定換了，就不沿用（S4 審查）。
        var polishedWith: String?
        /// 錄音中送了但字數太少、或被 OpenAI 拒收的段：錄音中不再送，停止後整理流水照 S2-2 重送、標漏字。
        var liveSkippedSegments: Set<Int> = []

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            segmentTexts = try container.decodeIfPresent(
                [Int: String].self,
                forKey: .segmentTexts
            ) ?? [:]
            transcriptID = try container.decode(UUID.self, forKey: .transcriptID)
            planVersion = try container.decodeIfPresent(Int.self, forKey: .planVersion)
            segments = try container.decodeIfPresent(
                [WAVSegmenter.Segment].self,
                forKey: .segments
            )
            suspectSegments = try container.decodeIfPresent(
                Set<Int>.self,
                forKey: .suspectSegments
            ) ?? []
            polishedSources = try container.decodeIfPresent(
                [String].self,
                forKey: .polishedSources
            ) ?? []
            polishedDrafts = try container.decodeIfPresent(
                [String].self,
                forKey: .polishedDrafts
            ) ?? []
            polishedWith = try container.decodeIfPresent(String.self, forKey: .polishedWith)
            liveSkippedSegments = try container.decodeIfPresent(
                Set<Int>.self,
                forKey: .liveSkippedSegments
            ) ?? []
        }

        /// 從第 1 段起連續轉好的那幾段接起來（中間缺一段就停在那裡）。
        var contiguousText: String {
            var texts: [String] = []
            while let text = segmentTexts[texts.count] {
                texts.append(text)
            }
            return texts.joined()
        }

        /// 先潤飾好的塊裡，口語稿跟 `chunks` 開頭一模一樣的有幾塊。
        func polishedPrefixCount(matching chunks: [String]) -> Int {
            let pairs = zip(polishedSources, chunks)
            return pairs.prefix { $0.0 == $0.1 }.count
        }

        /// 換成這份切法。起訖一樣的段留著已轉的字，對不上的作廢；切法版本換了全部作廢。id 留著。
        /// S4-1：錄音中先轉的段，停止後整份重切時起訖一樣，字就沿用，不再送一次。
        mutating func adopt(_ plan: [WAVSegmenter.Segment]) {
            let previous = planVersion == Self.currentPlanVersion ? segments ?? [] : []
            let keeps = { (index: Int) in
                index < previous.count && index < plan.count && previous[index] == plan[index]
            }
            segmentTexts = segmentTexts.filter { keeps($0.key) }
            suspectSegments = suspectSegments.filter(keeps)
            liveSkippedSegments = liveSkippedSegments.filter(keeps)
            planVersion = Self.currentPlanVersion
            segments = plan
        }
    }
}
