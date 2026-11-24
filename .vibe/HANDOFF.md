# Handoff: 組塊 Y「主力編輯器」六包進行中（分支 writer-tool，worktree E:\VoiceType-w0）

> 產出時間：2026-11-24 12:55。前一份在 `handoff/archive/2026-11-24-1255-換掉前.md`。
> 米 2026-11-24 兩句：「如果目標客戶是知識型創作者，把 app 當主要文字編輯工具，文章都在裡頭搞定，複製就能貼」「全做，不過開多個 subagent 做」。
> 出 TestFlight 要米當次明講，`v*` tag 不准自己打。推分支跑 CI、綠了快轉進 main 可以。

## ✅ 已完成
- 規格：`.vibe/主力編輯器-工作包.md`（共同規則＋Y1～Y6），派子代理照它。
- Y1 出口、Y2 資料安全與清單、Y3 AI 已併進 writer-tool（都還沒看到 CI 綠）。

## 🧩 剩下的工作
- [ ] Y4 編輯頁（E:\VoiceType-y4，分支 y4，子代理在跑）
- [ ] Y5 改寫稿可編輯（E:\VoiceType-y5，分支 y5，子代理在跑）
- [ ] 合併 y4、y5（衝突多半在 TranscriptDetailView.swift、+Menu）；Y5 的刪除要接 Y2 的 `TranscriptStore` 垃圾桶；`isBlankDraft` 兩邊都可能改
- [ ] Y6 選單與設定整理（規格同檔；模型存值一律不讀，測試 `AppSettingsTests` 有一條要跟著改）
- [ ] CI 修到綠（紅燈多半是 SwiftLint／編譯）
- [ ] 找沒參與的子代理獨立審查：資料不弄丟（垃圾桶、自動備份、改寫轉存、補錄存檔順序）、安全標準
- [ ] 帳本加組塊 Y、待驗清單加一段、快轉進 main（先 fetch）、砍 y1～y6 worktree

## ❓ 最後一起問米
- 加密金鑰要不要改成能跟 iCloud 鑰匙圈走（換手機還原才解得開；碰安全標準，改了難回頭）
- 「學到的習慣」留不留；舊編輯框何時刪
- 各代理的待確認：清單列顯示最後改的時間、單顆 * 夾中文不去、串文編號留在字裡、自動備份資料夾要真機驗

## 📌 決定
- 舊編輯框留一版當退路；iPad、iCloud 同步不在這輪。
- 格式檢查腳本在 scratchpad 的 fmt.sh（SwiftFormat 0.64.0 Windows 版，從 stdin 餵）；沒了就照 `handoff/archive/2026-11-04-0908.md` 重做。

## ⏭️ 下一步
1. `git -C E:\VoiceType-y4 log -3`、`y5` 看做完沒；做完就合併、派 Y6、跑 CI、審查、寫帳本，一路到底再回報米。
