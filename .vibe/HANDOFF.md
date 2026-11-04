# Handoff: 米的核心流程在真機跑通；0.1.5 上 TestFlight（左右滑三頁），等米試滑動並確認金鑰欄

> 產出時間：2026-11-04 09:08
> 前一份（2026-11-01 13:00）在 `handoff/archive/2026-11-01-1300.md`。
> **最重要的一句**：程式都已推上 GitHub；本機只多這個交接 commit，沒推（只改 `.vibe/`，推了也不會觸發 CI）。程式不用急著再寫，先問米 0.1.5 的滑動結果，再決定介面要改什麼。

## ✅ 這次完成了什麼

- 做完 C2～C6 修正、D6、首頁接流水、F1～F5、G1～G2、三位乾淨審查員的修正；帳本 C1～G2 全打勾。
- 跑通 CI：格式、規矩、編譯都過，73 個測試 0 失敗、1 條略過（檔案保護在模擬器讀回 nil，只能真機驗）。v0.1.4 那輪是 run 41328398620；最新 commit `b0b4f1e` 是 run 41332003133，也綠。
- 送 TestFlight：v0.1.4（build 5）、v0.1.5（build 6，run 41332550364，Apple VALID）。
- 米在真機貼金鑰、講一段、貼上，回「都ok」。只有這句，沒有逐步回報（跳過紀錄有記）。截圖看得到轉錄與潤飾真的成功。
- 做了三頁左右滑 `Screens/Root/RootPagerView.swift`：左文字稿、中首頁、右設定，打開停中間，上方小點可點；首頁拿掉「文字稿」「⋯」兩顆鈕。「打開這篇」換到文字稿頁再推那一篇，「去設定」換到設定頁。
- 修了真機截圖看到的：待轉錄列的 iOS 26 灰底與置中字；日期英文（`project.yml` 宣告 zh-Hant）。
- OpenAI 拒收（4xx）或讀不出來的錄音：自動續轉跳過、待轉錄清單標紅字讓米刪（只記在記憶體，重開再試一次）。
- 省 CI 費用（米看過帳單，VoiceType 當時 7.44 美元，macOS 335 分鐘）：
  - `ios-native-ci.yml` 只吃分支推送，而且只在 `ios-native/**` 或該檔改動時跑；推 tag 不重跑。
  - 格式、規矩、編譯都跑完才判紅，編譯沒過不跑測試。
  - SwiftFormat 釘 0.64.0 驗 SHA-256。
  - `desktop-release.yml` 只留手動（`v*` tag 不再觸發）。

## 🚧 還沒做完 / 待決定

1. **等米回兩件事（0.1.5 上）**：
   - 左右滑順不順、小點有沒有跟著動；進一篇文字稿後在正文中間左右滑會不會整頁換走（每頁各有 NavigationStack，可能打架，我驗不了）。會換走就改成只有最外層能滑。
   - 設定頁金鑰欄截圖是空的，連灰字「貼上金鑰」都沒有，米說沒刪過。我的判斷是 iOS 不讓密碼欄內容進截圖，**這只是推論，沒查證也沒實測**。請米直接看手機是不是點點、按眼睛看得到 `sk-` 嗎。真的空就是 bug，查 `SettingsView.loadKey`。
2. **介面審查還沒真的做**：米選了「先審查再改」，截圖有了，也做了滑動。截圖裡看到、還沒動的只有兩條：
   - 詳情頁底部三顆鈕只有圖示沒字，建議加字。
   - 整理好的面板內容擠上半部，下面空一大塊。
   完整審查該走 `domi-uiux-control` 的審查線，產出寫 `.uiux/審查紀錄.md`。玉米插圖、「收成第 N 根」、穀倉都還沒做，要回設計線、要素材。
3. **總待驗清單沒有逐步回報**：`操作清單-待驗.md` 是 0.1.4 版，裡面還寫「首頁右上⋯」「首頁左上文字稿」，要改成左右滑。鎖屏、來電、35 分鐘、25 分鐘續轉、備份都沒有米的原話。
4. **🧱 米定文案**：`切片帳本.md`「進行中」段的清單，米還沒看。另有：「先放著」vs 06 的「放著，好了通知我」；「匯出備份／匯入備份」在詞彙表是拿掉的說法；「沒有被扣款」對長錄音轉一半失敗不準。
5. **沒做的**：
   - 06 錄音面板「沒聽到聲音」。
   - `TranscriptionQueue` 沒有單元測試。
   - `TranscriptStoreTests` 會刪 Keychain 歷史金鑰（只准模擬器，規矩檔還沒加）。
   - 規矩檔還沒加「CI 一批才推一次」那條（之前提過要加，米還沒點頭；vibe-self-review、regression-guard 兩支 skill 預設實跑不用錢，要不要改也是米定）。
   - Xcode Cloud 免費額度能不能不靠 Mac 設定，提過要查，還沒查。
6. 組塊 H 範圍仍待米定；組塊 I（首頁定稿）被三頁滑動改了前提，要回頭更新 `.uiux/02-流程.md`、`03-線框/方向說明.md`（結構樹還是舊的「更多 → 設定」）。

## 📌 關鍵決策（別再爭論）

- 導覽：米 2026-11-02 定左右滑三頁，取代左上「文字稿」、右上「⋯」。
- 四件行為米回「照你的」：拒收的跳過並標紅字；潤飾失敗繼續下一筆；temperature 只給 gpt-4 系列（標準清單 D4 的 0.3 以此為準）；備份明文 JSON、設定頁有提醒。面板與續轉兩筆並行維持。
- 介面順序：先驗核心，再審查再改（米選的）；不走重做方向。
- 用的是 OpenAI API 金鑰，跟 ChatGPT 訂閱無關。TestFlight 本身要編譯，Expo Go 跑不了 Swift，不再討論。
- CI 要錢：一批做完才推一次；單片證據靠本機格式檢查＋乾淨審查員。

## 📂 下個會話最重要的檔案

- `.vibe/規矩檔.md`（必讀）、`.vibe/安全標準.md`（**下一個會話必讀**）
- `.vibe/切片帳本.md`「進行中」與跳過紀錄（真相源）、`.vibe/操作清單-待驗.md`
- `ios-native/MiSay/Screens/Root/RootPagerView.swift`、`Screens/Home/HomeView.swift`、`Screens/Transcripts/TranscriptDetailView.swift`、`Screens/Recording/RecordingResultView.swift`、`Screens/Settings/SettingsView.swift`
- 接近 file_length 300 的上限：`Recording/Recorder.swift`（300）、`Screens/Recording/RecordingSheetView.swift`（300）、`Screens/Transcripts/TranscriptDetailView.swift`（298）；超過 300 就紅，動之前先拆
- `.uiux/02-流程.md`、`.uiux/05-設計代號/`、`.uiux/06-首次體驗.md`

## ⏭️ 下一步從哪繼續

1. 問米：0.1.5 左右滑的結果、推進文字稿後滑動會不會換走、手機上金鑰欄是不是點點。
2. 照回答修。滑動打架就改外層結構；金鑰欄真的空就查 `loadKey`。
3. 用 `domi-uiux-control` 審查線跑米給的截圖，出問題清單給米排，至少含上面兩條。
4. 一批改完：本機格式檢查 → commit → 推一次 → CI 綠 → 打下一個 tag `v0.1.6`。
5. 順手改 `操作清單-待驗.md` 的導覽字眼。

本機格式檢查做法（SwiftFormat 0.64.0 Windows 版，讀資料夾會當掉，要一個檔一個檔從 stdin 餵）：

```bash
gh release download 0.64.0 --repo nicklockwood/SwiftFormat -p "SwiftFormat.amd64.msi"
```

用 `msiexec /a <msi> /qn TARGETDIR=<暫存夾>` 解開（不安裝），再 `swiftformat.exe stdin --config .swiftformat < 檔`。比對前先去掉 `\r`，不然每行都算不同。SwiftLint Windows 版缺 sourcekitd，本機跑不動，交給 CI。

## 🗑️ 雜訊

- 本機沒有 Swift、Docker 沒開：不要試本機編譯。
- 行長用字元數算（中文一字算 1），`awk length` 算位元組不準。
- `git commit` 被 pre-commit 擋時，`;` 接的 `git push` 照樣會推，曾白觸發一輪 CI（已取消）。commit 和 push 要用 `&&`。
- 畫面裡寫 `spacing: 0` 也會被 pre-commit 擋。
