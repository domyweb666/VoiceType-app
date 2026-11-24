import Foundation

/// 2026-11-08：找出改過還沒看的篇，把被改對的詞加進自訂詞彙。2026-11-25 起只在手機上認字，不送任何地方。
/// 什麼時候跑：收起鍵盤、離開文字稿、打開 App（上次來不及看的）。開關關著就不跑。
@MainActor
enum CorrectedWordsRunner {
    private static var isRunning = false

    /// 叫了就在背景跑，正在跑就不重複開。
    /// 收鍵盤時只看那一篇（`id`），不為了一篇把全部文字稿讀一次。
    static func start(only id: UUID? = nil, settings: AppSettings = .shared) {
        guard settings.autoVocabulary, !isRunning else {
            return
        }
        isRunning = true
        Task { @MainActor in
            await runOnce(only: id, settings: settings)
            isRunning = false
        }
    }

    static func runOnce(only id: UUID?, settings: AppSettings) async {
        // 從舊的看起：自動詞滿了先刪最舊的，留下來的才會是最近改的。
        for transcript in candidates(only: id).reversed() {
            guard let edit = transcript.unlearnedEdit else {
                continue
            }
            // 長稿比對要一點時間，不佔畫面那條線。
            let words = await Task.detached(priority: .utility) {
                CorrectedWords.find(from: edit.from, to: edit.to)
            }.value
            guard settings.autoVocabulary else {
                return
            }
            let added = settings.addAutoVocabulary(words)
            // 診斷紀錄只記數字，不記詞的內容（關於米說那頁的承諾）。
            DiagnosticLog.shared.record("自動詞彙：認出 \(words.count) 個，加 \(added.count) 個")
            markLearned(transcript.id, edit: edit)
        }
    }

    /// 讀不到就這次不看，下次再來；不影響任何字。
    private static func candidates(only id: UUID?) -> [Transcript] {
        let store = TranscriptStore()
        guard let id else {
            return (try? store.loadAll().transcripts) ?? []
        }
        let transcript = try? store.load(id: id)
        return [transcript].compactMap { $0 }
    }

    /// 存回前重讀一次：比對的這段時間人可能又改了字，只動 `learnedDraft`，不蓋掉新改的。
    /// 起點換過了（重新轉錄、接了錄音）就不記，不然下次會拿舊的那份來比。
    private static func markLearned(_ id: UUID, edit: (from: String, to: String)) {
        let store = TranscriptStore()
        guard var latest = try? store.load(id: id), latest.unlearnedEdit?.from == edit.from else {
            return
        }
        latest.learnedDraft = edit.to
        do {
            try store.save(latest)
        } catch {
            // 沒記到只是下次再看一次同一處，詞不會重複加。
            DiagnosticLog.shared.record("自動詞彙：看到哪沒記住 \(type(of: error))")
        }
    }
}
