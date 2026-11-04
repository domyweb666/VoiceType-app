# Handoff: C～G 全部寫完、CI 綠、v0.1.4（build 5）已上 TestFlight；等米照總待驗清單驗

> 產出時間：2026-11-01 13:00
> 前一份（2026-11-01 07:40）在 `handoff/archive/2026-11-01-0740.md`。
> **最重要的一句**：2026-11-02 補：CI 綠（run 41328398620，73 測試）、v0.1.4 build 5 上 TestFlight。總待驗清單在 `操作清單-待驗.md`。
> **CI 要錢**（macOS 0.062 美元／分鐘，米看過帳單）：一批做完才推一次。格式先在本機用 Windows 版 SwiftFormat 0.64.0 跑（讀資料夾會當掉，要一個檔一個檔從 stdin 餵：`swiftformat.exe stdin --config .swiftformat < 檔`）；SwiftLint Windows 版要 Swift 工具鏈，本機跑不動。
> 本機有一個沒推的 commit `ae3c1d7`（CI 只吃分支推送、推 tag 不重跑），跟下一批程式一起推，單獨推會白跑一輪。

## ✅ 這次完成了什麼（commit 由舊到新）

- `0690228` C2～C6 審查修正＋**D6** 錄音面板後半段（`Screens/Recording/RecordingResultView.swift`）＋**首頁接流水**（`MiSayApp` 一條 `TranscriptionQueue` 用 environment 傳；首頁出現與回前景續轉；「打開這篇」推 `TranscriptListView(opening:)`、「去設定」推設定）。
- `512fcad` **F1～F5**：`SettingsView` 潤飾區／使用習慣／關於米說；`VocabularyView`、`PolishPromptView`；`TranscriptionQueue` 每筆從 `AppSettings` 讀。
- `ef12455` **G1～G2**：`Backup/Backup.swift`、`Screens/Settings/BackupSection.swift`。
- `e42178d`、`7e9444d` D1～D5＋D7＋E 審查修正（重點：潤飾只對 gpt-4 系列帶 temperature；`ShareLink` 補 preview，原本會編譯失敗；`TranscriptDetailView` 拆出 `TranscriptStatusStrip`、`TranscriptTextFile`；流水新結局 `recordingUnreadable`、`recordingNotDeleted`、`draftNotSaved`）。
- `e8a8a6c` 第三位審查員修正（重點：首頁續轉不綁 `.task`，推頁不再砍整理；進度檔先定文字稿 id 避免重複一篇）＋帳本、state。
- 帳本 C1～G2 全部打勾（機器層＝靜態審查），「進行中」段有完整的假設、🧱 米定文案、要米決定的行為。

## 🚧 還沒做完 / 待決定（照這個順序）

1. **CI 預算**：米去 https://github.com/settings/billing/spending_limit 調高 Actions 上限。恢復後推 main 跑 `iOS Native CI`，紅的修到綠，再推 `v0.1.4`。預期有幾處紅（三位審查員都沒實跑工具）。
2. **米要決定的四件行為**（帳本「要米決定的行為」）：最舊一筆被 4xx 拒絕會卡住整條續轉；潤飾失敗要不要停；temperature 只對 gpt-4 系列（標準清單 D4 寫 0.3）；面板與續轉可能兩筆並行。另外：備份檔明文（設定頁有講），要米點頭。
3. **🧱 米定文案**：帳本「進行中」段的清單，加上第三位審查員提的：「先放著」vs 06 的「放著，好了通知我」、「匯出備份／匯入備份」在詞彙表是拿掉的說法、「沒有被扣款」對長錄音轉一半失敗不準。
4. 06 錄音面板「沒聽到聲音」狀態沒做（Recorder 要記最大音量）。
5. D5 `TranscriptionQueue` 沒有單元測試；`TranscriptStoreTests` 會刪 Keychain 歷史金鑰（只准模擬器，規矩檔還沒加）。
6. 全部編過之後重寫 `操作清單-待驗.md`：組塊 B（已有）＋C～G 帳本的「人類驗收」句。D6、F、G 沒寫標準清單與黃金行為（跳過紀錄有記），以帳本句為準。
7. 組塊 H 範圍待米定；組塊 I 用 D。

## 📌 關鍵決策

- 潤飾 temperature 只對 `gpt-4` 開頭的模型送（GPT-5 系列不收，網頁版 `docs/index.html:569` 同做法）。
- 整理用不綁畫面的 `Task`：面板收起、首頁推頁都不中斷；自動複製只在面板還開著時做。
- 進度檔 `Progress.transcriptID` 先定好，存口語稿用同一個 id，重跑不會多一篇。
- 錄音檔刪不掉不再 `try?` 吞，停下並說出來；先刪錄音再清切段與進度。
- 備份：JSON 明文、不含金鑰、按分享才組檔；匯入先驗大小→是不是米說的檔→版本→內容，同 id（含備份內重複）跳過，確認後才寫。

## 📂 下個會話最重要的檔案

- `.vibe/切片帳本.md`「進行中」段（真相源）、`.vibe/規矩檔.md`、`.vibe/state.json`
- `ios-native/MiSay/PendingQueue/TranscriptionQueue.swift`、`Screens/Recording/RecordingResultView.swift`、`Screens/Settings/BackupSection.swift`、`Screens/Transcripts/TranscriptDetailView.swift`
- 接近上限：`Recording/Recorder.swift`、`Screens/Recording/RecordingSheetView.swift` 都剛好 300 行（file_length 超過 300 就紅），`TranscriptDetailView.swift` 298 行。

## ⏭️ 下一步從哪繼續

1. 問米：CI 預算調了沒、四件行為怎麼定、文案要不要現在看。
2. CI 能跑就推 main，照紅燈修；綠了推 `v0.1.4`，重寫總待驗清單。

## 🗑️ 雜訊

- 本機沒有 Swift、Docker 沒開：不要試本機編譯。
- 行長要用字元數算（中文一字算 1），`awk length` 算的是位元組，不準。
- `desktop-release.yml` 也吃 `v*` tag 的事米還沒決定。
