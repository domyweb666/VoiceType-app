# Handoff: 米定唯一目標是穩定性；第一批「錄音不斷」v0.1.6 上 TestFlight，等米驗；第 0 步等米給東西

> 產出時間：2026-11-04 11:20
> 前一份在 `handoff/archive/2026-11-04-0908.md`。
> **最重要的一句**：下一步是米的手。先問第一批驗得怎樣、要診斷紀錄檔，再談第二批。左右滑、金鑰欄、介面審查全部往後放。

## ✅ 這次完成了什麼

- 米說「我的唯一目標是穩定性」，看完 `.vibe/穩定性改進方案.md` 回「照建議開工」。決定都寫進 PRD、產品定稿、架構藍圖、標準清單、帳本（組塊 S）、規矩檔。
- 第一批 S1～S6 寫完，commit `d251dd9`：
  - `Recorder` 搬到 App 層；收音拆成 `MicrophoneCapture`，每次接回都換新引擎、接頭、轉換器，同一個檔接著寫。
  - 打斷結束、回前景、每 10 秒都試接；換耳機與音訊服務重置也重建。
  - `CaptureWatch`（純邏輯，有測試）判斷卡住、試接、推通知、斷幾次。
  - `RecordingAlarm`：錄音時一直往後推的本機通知，App 被殺或卡住 90 秒內響。完成面板問通知權限（`RecordingAlarmPrompt`）。
  - `RecordingSpace`：開錄前與錄音中看空間；寫到一半失敗退回完整位置。
  - 撿回救回檔時跳過正在錄的檔（`HomeView`）。
  - `DiagnosticLog`：只記時間、事件、數字；設定 → 關於米說 → 匯出診斷紀錄。
- 機器層：乾淨審查員審一輪，列的都修了；CI run 41764064252 第一推就綠，94 個測試 0 失敗 1 略過；`v0.1.6` build 7，run 41764870533，Apple VALID。
- 第 0 步腳本在 session 暫存資料夾的 `stage0.py`（會話結束就不在了，內容照方案第 0 步重寫即可），只試過切音檔與組請求，沒打過 OpenAI。

## 🚧 還沒做完 / 待決定

1. **等米驗第一批**：清單在 `操作清單-待驗.md` 最上面。要米的原話和診斷紀錄檔，只回「都 ok」要再問一次。App 在背景時接不接得回去，Apple 文件和開發者回報講得不一樣，只有這輪看得出來。
2. **第 0 步等米給**：OpenAI 金鑰（腳本在終端機用看不見的輸入問，不准貼進對話）、11 分鐘以上他自己講話的音檔、手機匯出的備份檔。結果決定第二批切段長度與等待秒數、第三批的提示詞和模型。
3. **第二批「字一定出得來」（v0.1.7）**：等第一批驗過才切細，內容見方案。動手前先拆 `PendingQueue/TranscriptionQueue.swift`（型別 192 行，上限 200）；`Recording/Recorder.swift` 295 行、`Screens/Transcripts/TranscriptDetailView.swift` 298 行、`Screens/Settings/SettingsView.swift` 288 行也很緊。
4. **第三批「語感」（v0.1.8）**：刪法米照建議選乙，要用他的真稿跑給他讀才定。`gpt-4o-mini` 2027-01-14 關閉，設定頁第二個選項要換。
5. **第四批「鎖屏時也整理好」**：等米走過一次再決定，AI 建議邊錄邊轉。
6. **🧱 米定文案**：`切片帳本.md`「進行中」的 🧱 段多了第一批的句子。
7. **Privacy Manifest**：專案沒有 `PrivacyInfo.xcprivacy`，這批多用了磁碟空間 API。build 7 Apple 回 VALID；送審前要補。

## 📌 關鍵決策（別再爭論）

- 唯一目標是穩定性；介面往後放（米 2026-11-04）。
- 打斷後自動接回，推翻 C3「不准自動續錄」。
- 錄音檔存好口語稿後留 7 天（第二批生效）。金鑰改成開機第一次解鎖後可讀（第二批生效）。
- 重複句只算連著講的；刪法乙（第三批生效）。
- 一批才推一次 CI，每批米驗過才做下一批。
- 之前的決定照舊：左右滑三頁、API 金鑰跟 ChatGPT 訂閱無關、TestFlight 要編譯。

## 📂 下個會話最重要的檔案

- `.vibe/穩定性改進方案.md`（全部計畫與查證來源）
- `.vibe/切片帳本.md`「組塊 S」「進行中」「跳過紀錄」
- `.vibe/操作清單-待驗.md` 最上面
- `.vibe/規矩檔.md`、`.vibe/安全標準.md`、`.vibe/標準清單.md` 最後面
- `ios-native/MiSay/Recording/`

## ⏭️ 下一步從哪繼續

1. 問米第一批的結果，收診斷紀錄檔，對照「收音接上」「打斷」「接回失敗」的行數判斷。
2. 紅的修；要改就再一批，版本 `v0.1.7` 順延。
3. 米給金鑰與音檔就跑第 0 步，把數字寫回方案。
4. 第一批過了，用 `vibe-spec-standards` 開第二批。

本機格式檢查（SwiftFormat 0.64.0 Windows 版）：

```bash
gh release download 0.64.0 --repo nicklockwood/SwiftFormat -p "SwiftFormat.amd64.msi"
```

用 `msiexec /a <msi> /qn TARGETDIR=<暫存夾>` 解開，再從 `ios-native/` 一個檔一個檔 `swiftformat.exe stdin --config .swiftformat < 檔`，比對前先去掉 `\r`。SwiftLint 本機跑不動，行長（100 字元，中文算 1）、檔長（300）、型別長（200）、函式長（40）要自己算。

## 🗑️ 雜訊

- 本機沒有 Swift：不要試本機編譯。
- commit 和 push 要用 `&&`，pre-commit 擋下時才不會白推。
- Python 腳本裡有反斜線或很多引號時，用 Write 寫檔再跑，不要走 heredoc（這次 heredoc 兩次出事）。
- 本機多一個只改 `.vibe/`、`.uiux/` 的文件 commit 沒推，推了也不會觸發 CI。
