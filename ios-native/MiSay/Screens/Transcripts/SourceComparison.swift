/// 「AI 改了什麼」比完的結果：逐字的差別，加上可能改了意思的地方。
struct SourceComparison: Equatable, Sendable {
    let diff: PolishDiff
    /// 接著錄過的篇順序對不上，不比，是 nil。
    let meaning: MeaningCheck?
}
