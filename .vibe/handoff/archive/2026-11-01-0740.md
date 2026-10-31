# Handoff: 組塊 B 到齊上 TestFlight（0.1.3）、C 全部與 D 大半做完但沒 CI、E 有草稿；下一步先過審查員、補 D6、接首頁流水

> 產出時間：2026-11-01 07:40
> 前一會話的最後狀態，給下一個會話接續用。前一份（2026-11-01 02:20）在 `handoff/archive/`。
> **最重要的一句**：從 C1 起所有程式都沒有編譯過（GitHub Actions 預算用完），只有本機掃描與乾淨審查員的靜態審查。米說「直接往下做，做到剩我實測」。

## ✅ 這次完成了什麼

- **B2** `OpenAI/OpenAIClient.swift`：只連 `https://api.openai.com`、金鑰從 B1 讀、逾時 60／15 秒、`Failure` 分可重試（429 速率、5xx、逾時、斷線）／不可重試（401／403、429 額度、4xx、形狀不對）、錯誤不帶正文；`verifyAPIKey()` 打 `GET /v1/models`。16 個 `test連線` 測試，CI 綠（run 41238307172 之前的 41233908635）。米跳過立即驗。
- **B3** `Screens/Settings/SettingsView.swift`：金鑰區（遮住、眼睛、儲存並驗證、四句文案、刪除、去申請金鑰）；`KeyStatus` 把 M11 錯誤翻成句子；5 個測試；CI 綠 run 41238307172。
- **v0.1.3 上 TestFlight**（米：「推 v0.1.3」）：iOS Release run 41239012112 綠，Apple VALID，build 4。組塊 B 的批次驗清單在 `操作清單-待驗.md`（米還沒驗；清單開頭三個小決定：五句措辭、返回自動存、刪除確認）。
- **米的指令**（帳本開頭有記）：「直接往下做，把該做的功能都做完，做到剩我實測」→ D、E、F、G 視為放行；每片走查／對齊／人驗全記跳過；CI 預算用完後米再說「直接往下做」→ 沒有 CI 也繼續。
- **C1** 錄音：`Recording/WAVFileWriter.swift`（自己寫的 WAV，邊錄邊落地，檔頭長度欄被殺掉時是 0）、`Recording/Recorder.swift`（AVAudioEngine → 16 kHz 單聲道 Int16、tap 寫檔、音量 20 Hz、`fileProtection` 常數在這裡）、`PendingQueue/PendingRecordings.swift`（Application Support/Pending）、`Screens/Recording/RecordingSheetView.swift`（半頁不可下滑、計時、波形、80pt 停止鈕呼吸、觸覺）、`HomeView` 鈕升起面板、`project.yml` 加 `NSMicrophoneUsageDescription`。審查員六處修正已套。
- **C2** 被拒面板（兩句＋「打開『設定』」直開米說設定頁＋「先不要」）。
- **C3** `UIBackgroundModes: audio`；`Recorder` 聽中斷通知、`isInterrupted`、`resume()`；面板「通話時暫停了，已錄到的 X 都在。」＋繼續錄／停止；**不自動續錄**。
- **C4** `WAVFileWriter.repairHeader(at:)`；`PendingRecordings.recoverAbandonedRecordings()`（補檔頭、搬進待轉錄、空檔丟）；`HomeView` 第一次出現先撿回。
- **C5** 無新程式，一條 35 分鐘寫檔測試。
- **C6** 首頁待轉錄列（0 個不出現）→ `Screens/Pending/PendingListView.swift`（時間、長度、左滑刪除過動作表）；`PendingRecordings.list()／delete()`。
- **D1** `Storage/Transcript.swift`、`TranscriptStore.swift`（AES-GCM、原子寫入、壞檔搬 Unreadable/ 不刪、最新在上）、`TranscriptEncryptionKeyStore.swift`（Keychain ThisDeviceOnly，跟 B1 分開）。6 測試。
- **D2** `Transcription/MultipartForm.swift`、`TranscriptionPrompt.swift`（200 字）、`Transcriber.swift`（模型 **`gpt-transcribe`**）。**D3** `WAVSegmenter.swift`（FileHandle 切 10 分鐘一段）、`RecordingTranscriptionJob.swift`（進度檔、只送沒成功的段、`onSegment` 回呼）。**D4** `Polishing/Polisher.swift`（system／user 分開、0.3、預設提示詞＝舊骨架＋米六條規矩、`gpt-5.4-mini` 預設、`gpt-4o-mini` 第二選項）。M11 加 `OpenAIClient.retrying`（只對可重試錯、次數間隔呼叫端給）。假伺服器 `FakeOpenAIServer` 會收正文、排回答、計數。12 測試。
- **D5** `PendingQueue/TranscriptionQueue.swift`（@Observable @MainActor；有金鑰才送、口語稿存好才刪錄音與切段、潤飾失敗口語稿在、`processPending` 從最舊開始一筆失敗就停、`inFlight` 不重送、`activity` 給面板畫第 N／M 段）。**還沒接到任何畫面**。
- **D7** `Screens/Transcripts/TranscriptListView.swift`（最新在上、讀不到篇數橫幅、空狀態）＋ `TranscriptDetailView.swift`。
- **E1～E6 草稿**（commit 11881ae，未審查）：詳情頁文字稿｜口語稿分段、底部工具列複製／重新潤飾／分享、改字 1 秒自動存、「⋯」刪除 → 清單「已刪除・復原」5 秒、重新潤飾蓋掉或另存＋取消＋失敗一行、分享用 `Transferable` 純文字檔（才有「儲存到檔案」）、清單 `.searchable` 與「沒有包含『x』的文字稿」＋清除搜尋。
- **M7** `Settings/AppSettings.swift`（UserDefaults：autoCopy、vocabulary、polishPrompt＋還原、polishModel 二選一）。**還沒有任何畫面用它**；`TranscriptionQueue` 仍用 M4／M3 預設值。
- 規矩檔回灌：SwiftLint 預設規則也算數（錯誤日誌 +1）。

## 🚧 還沒做完 / 待決定（下個會話照這個順序）

1. **C2～C6 與 D1～D4 的審查結果都收到了，記在帳本「進行中」段（含該修的清單，一處都還沒修）**。D1～D4 有兩個編譯錯誤（Transcriber 與 WAVSegmenter 的 `guard let` 重複宣告）要先修。D5、D7、E、M7 還沒審。它們的輸出檔（若還在）：
   - 位置：這台電腦的 Temp 下 `claude/E--VoiceType/<這個會話的 id>/tasks/`（會話 id 以 992d0997 開頭），檔名 `a9e68c1dd23157727.output`（C2～C6）與 `a78ec23ccd697bc29.output`（D1～D4）。絕對路徑不寫進 repo。
   檔案是 JSONL 逐字稿，用 `tail -c 20000` 找最後的 result；找不到就重開審查員（審查 prompt 的寫法照帳本裡 C1、B3 的五查核格式）。E1～E6、D5、D7、M7 也還沒審。
2. **D6 錄音面板後半段**（`RecordingSheetView.swift`，還沒動）：停止後接 `TranscriptionQueue.process`；狀態「整理中…」＋「第 2／3 段」（讀 `queue.activity`）、潤飾中、完成（自動複製照 `AppSettings.shared.autoCopy`、「好了，已經複製」、「打開這篇」推到詳情、觸覺 transcriptReady／copied）、失敗第一句「錄音還在待轉錄，沒有被扣款。」＋原因（沒網路／金鑰沒有用）＋「重試」「去設定」「完成」、沒金鑰「錄音收好了，在待轉錄。設定金鑰後會自動整理」＋「去設定金鑰」、潤飾失敗「口語稿已經存好，潤飾沒有成功。」＋重試潤飾（E4 的邏輯）、「先放著」收起面板讓流水在背景跑。文案全在 `.uiux/06-首次體驗.md` 錄音面板狀態表。「收成第 N 根」只留位置。
3. **首頁接流水**：`HomeView` 持有 `TranscriptionQueue`（或 `MiSayApp` 建一個傳下去）；`.task` 與 scenePhase 變 active 時 `processPending()`；面板收起後重算待轉錄數。
4. **F1～F5 畫面**（`SettingsView.swift`）：潤飾區（模型 Picker 二選一＋說明、自訂詞彙增刪、潤飾提示詞編輯頁＋還原預設）、使用習慣（自動複製開關）、關於（版本號）。`TranscriptionQueue` 改成從 `AppSettings.shared` 讀模型／提示詞／詞彙；D6 自動複製讀它。F5 字級跟系統走已成立（全用系統文字樣式）。
5. **G1～G2** `Backup/`：匯出全部文字稿成一個 JSON 檔（不含金鑰）→ ShareLink；沒東西按鈕變灰並說為什麼。匯入：`.fileImporter`、先驗格式與大小、**合併不覆蓋**（同 id 跳過）、畫面講清楚會加幾篇、米同意才做、壞檔說哪裡壞。
6. **CI 預算**：米去 https://github.com/settings/billing/spending_limit 把 Actions 上限從 0 調高。恢復後：推 main 讓 `iOS Native CI` 跑，紅的回頭修（預期會有幾處：審查員沒實跑 SwiftFormat／SwiftLint）；然後再推 `v0.1.4`。每輪約 3 分鐘 Mac 機器時間，一分鐘算十分鐘。
7. **總待驗清單**：全部編過之後重寫 `操作清單-待驗.md`：組塊 B（已有）、C（真機：鎖屏 2 分鐘、來電、滑掉重開差不到 5 秒、35 分鐘、刪待轉錄）、D（講 2 分鐘停止→草稿已複製、5 分鐘換話題分段、同一件事講三次只留一次、常用詞、「這是我講的」、整理中關網路→口語稿在歷史、25 分鐘轉一半斷網→只接著轉失敗段、飛航錄完關掉→自己轉好）、E、F、G 的帳本驗收句。
8. 組塊 H 範圍仍待米定（通知、捷徑、匯入音檔、刪除全部資料等）；組塊 I 用 D。
9. 審查員指出但沒做的：`TranscriptionQueue` 刪錄音時用假的 `Recording` 物件（應該給 `delete(url:)`）；`RecordingSheetView`「鎖住螢幕也會繼續錄」在 C3 之前是假的（現在 C3 做了）；波形 token 借用 `Shape.primaryTap` 當高度、`Space.xs` 當柱寬（該回設計線加代號）；檔案保護測試在模擬器可能回 nil 變紅。

## 📌 關鍵決策（這次定下來的）

- 轉錄模型 `gpt-transcribe`（舊版 `gpt-4o-mini-transcribe` 已 Deprecated、2027-02-26 關閉；每分鐘 0.0045 美元）；潤飾預設 `gpt-5.4-mini`（0.75／4.50 美元每百萬 token）、第二選項 `gpt-4o-mini`（Deprecated，0.15／0.60）。2026-11-01 官方文件查證。米可改。
- 錄音檔、歷史檔、進度檔的檔案保護都用「第一次解鎖後可用」（鎖屏錄音與背景整理要寫得進去），歷史另外 AES-GCM。
- 來電中斷後不自動續錄，面板問「繼續錄」「停止」（首次體驗檔那列有兩顆鈕）。
- 重試迴圈放 M11 `retrying`，次數與間隔由 M3（4 次）／M4（3 次）給，2 秒起倍增。
- 錄音檔「口語稿存進歷史之後才刪」；進度檔與切段跟錄音檔放一起、一起清。
- 429 正文解不開時當速率限制（可重試）；URLError 不明代碼與憑證錯不重試。
- 沒有 CI 期間：每片只靠本機行長掃描＋pre-commit＋乾淨審查員；帳本開頭有記，恢復後從 C1 起補跑。

## 📂 下個會話最重要的檔案

- `.vibe/HANDOFF.md`（這份）、`.vibe/切片帳本.md`（真相源：「進行中」段有 C1～D4 的計畫與自審證據、跳過紀錄、米指令）、`.vibe/標準清單.md`（C1、C2、C3～C6、D1～D4 的標準都 append 在同一檔）、`.vibe/黃金行為.md`（到第 30 條）、`.vibe/規矩檔.md`、`.vibe/錯誤日誌.md`
- `ios-native/MiSay/`：`Recording/`、`PendingQueue/`、`Transcription/`、`Polishing/`、`Storage/`、`Settings/AppSettings.swift`、`Screens/{Home,Recording,Pending,Transcripts,Settings}`
- `ios-native/MiSayTests/`：16 個測試檔，`FakeOpenAIServer` 在 `OpenAIClientTests.swift`
- `.uiux/06-首次體驗.md`（D6 文案）、`.uiux/05-設計代號/詞彙表.md`、`.uiux/03-線框/線框/米說線框.html`
- 共用筆記夾（發起會話的 side-session-notes）：`B2-交接便條.md`

## ⏭️ 下一步從哪繼續

1. 讀這份、規矩檔。state.json 的 station 是 `self-review`（C2～C6、D1～D4、D5、D7、E、M7 都等審查）。
2. 先撈兩個審查員的輸出檔；撈不到就重開審查員，一次審「C2～C6」、一次審「D1～D5＋D7＋E＋M7」。修完 commit。
3. 做 D6、接首頁流水（上面 2、3），再 F、G。每批一個審查員。
4. 等米把 Actions 預算調高：推 main 看 CI，紅的修到綠；推 `v0.1.4`；重寫總待驗清單給米。

## 🗑️ 這次會話的雜訊

- B2 立即驗、B3 走查、C～G 全部人驗閘：米明說跳過，都記在跳過紀錄，不用再問。
- Docker 沒開、本機沒 Swift：不要再試本機編譯，等 CI。
- `desktop-release.yml` 也吃 `v*` tag 的事還沒處理，米沒決定。
