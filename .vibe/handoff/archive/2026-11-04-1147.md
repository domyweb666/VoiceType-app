# Handoff: 米定唯一目標是穩定性；第一批「錄音不斷」v0.1.6 在 TestFlight 等米驗；第 0 步工具備好，等米給音檔與備份檔

> 產出時間：2026-11-04 11:47
> 前一份在 `handoff/archive/2026-11-04-0908.md`。
> **最重要的一句**：下一步是米的手。先問米要先驗第一批還是先跑第 0 步，不要自己往第二批寫。左右滑、金鑰欄、介面審查全部往後放。

## ✅ 這次完成了什麼

- 查完程式與官方文件，寫出 `.vibe/穩定性改進方案.md`；米回「照建議開工」。決定都寫進 PRD、產品定稿、架構藍圖、標準清單、帳本（組塊 S）、規矩檔。
- 第一批 S1～S6 寫完，commit `d251dd9`：
  - `Recorder` 搬到 App 層；收音拆成 `MicrophoneCapture`，每次接回都換新引擎、接頭、轉換器，同一個檔接著寫。
  - 打斷結束、回前景、每 10 秒都試接；換耳機與音訊服務重置也重建；來電橫幅不打斷。
  - `CaptureWatch`（純邏輯，有測試）判斷卡住、試接、推通知、斷幾次；接上就斷連續三次才慢下來。
  - `RecordingAlarm`：錄音時一直往後推的本機通知，App 被殺或卡住 90 秒內響。完成面板問通知權限（`RecordingAlarmPrompt`）。
  - `RecordingSpace`：開錄前與錄音中看空間，兩個讀數取大的；寫到一半失敗退回完整位置。
  - 撿回救回檔時跳過正在錄的檔（`HomeView`）。
  - `DiagnosticLog`：只記時間、事件、數字；設定 → 關於米說 → 匯出診斷紀錄。
- 機器層：乾淨審查員審一輪，列的都修了；CI run 41764064252 第一推就綠，94 個測試 0 失敗 1 略過；`v0.1.6` build 7，run 41764870533，Apple VALID。
- 真機上什麼都還沒驗。
- 第 0 步腳本 `stage0.py` 寫好，用假回應整條跑過，沒打過 OpenAI。工具都放在 `.vibe/local/`（已加進 `.gitignore`，不進 repo）。

## 🚧 還沒做完 / 待決定

1. **米還沒回答**：先驗第一批，還是先跑第 0 步。上個會話問了，米只回「先寫 handoff」。我建議先驗第一批，第 0 步可以同時跑，兩件事互不影響。
2. **等米驗第一批**：清單在 `操作清單-待驗.md` 最上面。要米的原話和診斷紀錄檔，只回「都 ok」要再問一次。App 在背景時接不接得回去，Apple 文件和開發者回報講得不一樣，只有這輪看得出來。也要問手機型號和 iOS 版本。
3. **第 0 步等米給**：11 分鐘以上他自己講話的音檔路徑、手機匯出的備份檔路徑。金鑰由腳本在終端機用看不見的輸入問，不准貼進對話。結果決定第二批切段長度與等待秒數、第三批的提示詞和模型。
4. **第二批「字一定出得來」（v0.1.7）**：等第一批驗過才切細，內容見方案。動手前先拆 `PendingQueue/TranscriptionQueue.swift`（型別 192 行，上限 200）；`Recording/Recorder.swift` 295 行、`Screens/Transcripts/TranscriptDetailView.swift` 298 行、`Screens/Settings/SettingsView.swift` 288 行也很緊。路徑從 `ios-native/MiSay/` 算起。
5. **第三批「語感」（v0.1.8）**：刪法米照建議選乙，要用他的真稿跑給他讀才定。`gpt-4o-mini` 2027-01-14 關閉，設定頁第二個選項要換。
6. **第四批「鎖屏時也整理好」**：等米走過一次再決定，AI 建議邊錄邊轉。
7. **🧱 米定文案**：`切片帳本.md`「進行中」的 🧱 段多了第一批的句子，米還沒看。
8. **Privacy Manifest**：專案沒有 `PrivacyInfo.xcprivacy`，這批多用了磁碟空間 API。build 7 Apple 回 VALID；送審前要補。

## 📌 關鍵決策（別再爭論）

- 唯一目標是穩定性；介面往後放（米 2026-11-04）。
- 打斷後自動接回，推翻 C3「不准自動續錄」。
- 錄音檔存好口語稿後留 7 天（第二批生效）。金鑰改成開機第一次解鎖後可讀（第二批生效）。
- 重複句只算連著講的；刪法乙（第三批生效）。
- 一批才推一次 CI，每批米驗過才做下一批。
- 之前的決定照舊：左右滑三頁、API 金鑰跟 ChatGPT 訂閱無關、TestFlight 要編譯。

## 📂 下個會話最重要的檔案

- `.vibe/穩定性改進方案.md`（全部計畫與查證來源）
- `.vibe/切片帳本.md`「組塊 S」「進行中」「跳過紀錄」（真相源）
- `.vibe/操作清單-待驗.md` 最上面
- `.vibe/規矩檔.md`（必讀）、`.vibe/安全標準.md`（**下一個會話必讀**）、`.vibe/標準清單.md` 最後面
- `ios-native/MiSay/Recording/`
- `.vibe/local/`：`stage0.py`（第 0 步）、`check_swift.py`（本機格式與長度檢查）、`lint_scan.py`（行數掃描）

## ⏭️ 下一步從哪繼續

1. 問米：第一批驗了嗎，第 0 步要不要先跑。把音檔路徑、備份檔路徑、手機型號、iOS 版本一次要齊。
2. 米有回報第一批：收診斷紀錄檔，對照「收音接上」「打斷」「接回失敗」的行數判斷。紅的修，再一批，版本 `v0.1.7` 順延。
3. 米給了音檔和備份檔就跑第 0 步：
   - 先用 Bash 把兩個檔複製成 `.vibe/local/input/audio.<原副檔名>`、`.vibe/local/input/backup.json`。`run_in_terminal` 只收 ASCII，中文路徑打不進去。
   - 用 `run_in_terminal`（標題 `Stage 0`）跑 `python .vibe/local/stage0.py all .vibe/local/input/audio.<原副檔名> .vibe/local/input/backup.json`，告訴米終端機會問金鑰、畫面不顯示字。不准要米把金鑰貼進對話。
   - 跑完讀 `.vibe/local/stage0-out/summary.txt`（只有數字）。`提示詞對照.md` 含米講的話，給米讀，不准進 repo。
   - `languages[]` 這個欄位名稱沒打過真 API，回 400 就先改腳本。
   - 把數字寫回 `.vibe/穩定性改進方案.md`，確認 5 分鐘切段、180 秒等待要不要調。
4. 第一批過了，用 `vibe-spec-standards` 開第二批。

本機格式檢查：`python .vibe/local/check_swift.py`（不給檔名就查 git 有改動的 Swift 檔，加 `--fix` 直接改）。它用 `.vibe/local/sf/` 裡的 SwiftFormat 0.64.0，也會查行長 100、檔長 300 和幾條自訂規矩。`python .vibe/local/lint_scan.py` 列型別長（上限 200）、函式長（上限 40）。SwiftLint 本機跑不動，交給 CI。

## 🗑️ 雜訊

- 本機沒有 Swift：不要試本機編譯。
- commit 和 push 要用 `&&`，pre-commit 擋下時才不會白推。
- Python 腳本裡有反斜線或很多引號時，用 Write 寫檔再跑，不要走 heredoc（這次出事兩次，反斜線會被吃掉）。
- 本機有三個只改 `.vibe/`、`.uiux/`、`.gitignore` 的文件 commit 沒推；`.vibe` 與 `.gitignore` 的改動不會觸發 CI。
