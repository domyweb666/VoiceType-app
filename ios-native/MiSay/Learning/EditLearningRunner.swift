import Foundation

/// 2026-11-08：找出改過還沒學的篇，一篇一篇送 `EditLearner`，學到的詞與習慣寫回設定。
/// 什麼時候跑：離開文字稿詳情頁、App 回到前景。兩個開關都關著就不跑；沒網路、沒金鑰、失敗都不動，下次再試。
@MainActor
enum EditLearningRunner {
    /// 一次最多學幾篇，免得一回前景就連送一串。
    static let maxPerRun = 3
    private static var isRunning = false

    /// 叫了就在背景跑，正在跑就不重複開。
    static func start(settings: AppSettings = .shared) {
        guard settings.isLearningFromEdits, !isRunning else {
            return
        }
        isRunning = true
        Task { @MainActor in
            await runOnce(settings: settings)
            isRunning = false
        }
    }

    static func runOnce(settings: AppSettings, learner: EditLearner = EditLearner()) async {
        guard let all = try? TranscriptStore().loadAll().transcripts else {
            return
        }
        let pending = all.filter { $0.unlearnedEdit != nil }.prefix(maxPerRun)
        for transcript in pending {
            guard settings.isLearningFromEdits else {
                return
            }
            let learned = await learn(transcript, settings: settings, learner: learner)
            guard learned else {
                return
            }
        }
    }

    /// 學完把 `learnedDraft` 記成這次的文字稿。只有標點的修改不送，直接記成學過。回 false 表示這次先停。
    private static func learn(
        _ transcript: Transcript,
        settings: AppSettings,
        learner: EditLearner
    ) async -> Bool {
        guard let edit = transcript.unlearnedEdit else {
            return true
        }
        let hunks = EditDiff.hunks(from: edit.from, to: edit.to)
        if !hunks.isEmpty {
            do {
                let result = try await learner.learn(
                    from: hunks,
                    currentHabits: settings.learnedHabits,
                    wantsHabits: settings.learnFromEdits,
                    model: settings.polishModel
                )
                apply(result, hunkCount: hunks.count, settings: settings)
            } catch {
                DiagnosticLog.shared.record("從修改學習沒成功：\(error)")
                return false
            }
        }
        markLearned(transcript.id, draft: edit.to)
        return true
    }

    private static func apply(_ result: EditLearner.Result, hunkCount: Int, settings: AppSettings) {
        let added = settings.autoVocabulary ? settings.addAutoVocabulary(result.vocabulary) : []
        if settings.learnFromEdits {
            settings.learnedHabits = result.habits
        }
        // 診斷紀錄只記數字，不記詞與習慣的內容（關於米說那頁的承諾）。
        DiagnosticLog.shared.record(
            "從修改學習：\(hunkCount) 處修改，加 \(added.count) 個詞，習慣 \(settings.learnedHabits.count) 條"
        )
    }

    /// 存回前重讀一次：學的這段時間人可能又改了字，只動 `learnedDraft`，不蓋掉新改的。
    private static func markLearned(_ id: UUID, draft: String) {
        let store = TranscriptStore()
        guard var latest = try? store.loadAll().transcripts.first(where: { $0.id == id }) else {
            return
        }
        latest.learnedDraft = draft
        try? store.save(latest)
    }
}
