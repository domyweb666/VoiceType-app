# Handoff: 統一風格從畫布做進 App，v0.1.7 build 8 已上 TestFlight；下一步是米先走介面、再驗錄音不斷

> 產出時間：2026-11-08 13:23
> 前一份在 `handoff/archive/2026-11-07-2359-補六前.md`（含 11/04 到 11/07 的六條補充：功能盤點、刪音檔時機、刀法、compare 結果、第三批模型）。那份的「穩定性」部分照舊有效，這份只把介面這一輪接上。
> **最重要的一句**：下一步是米的手。米選了「先走介面」，清單在 `.vibe/操作清單-待驗.md` 最上面。等他回報，不要自己往第二批寫。
> **2026-11-08 補**：米定潤飾提示詞不給改、改二選一（保留原聲 v2.1 預設／大幅潤飾＝舊預設），米說「現在就做」：片 P1 做完，v0.1.8 build 9 上 TestFlight 蓋掉 0.1.7。待驗清單最上面加「潤飾二選一」，統一風格與錄音不斷都改在 0.1.8 驗。模型還是 5.4-mini，換 luna 留在第三批。

## ✅ 這次完成了什麼

- 開 Design 畫布 https://claude.ai/artifact/S6UsLgtxX9FkFgkHSJXrwV （私有，22 張：風格總表、首頁、錄音面板七狀態、文字稿五張、設定三張、深色四張）。米改過兩次錄音鈕，定案快門式；首頁提示改「按中間的鈕」。
- 設計代號 v2 進 `.uiux/05-設計代號/`：Tokens.swift、contrast-pairs.json、對比檢查表（19 組四模式全過）、使用規則（新加 11～15 條），`06-首次體驗.md` 文案、閘門紀錄、lessons 各一條。commit c086966。
- 做進 App（組塊 U 四片）：顏色資源 15 個（每色淺／深／增加對比）、App Tokens.swift 同步、六個共用元件（`PrimaryButtonStyle`、`TextButtonStyle`、`StatusStrip`、`IconCircle`、`RecordButtonLabel`、`CornIllustration`）、13 個畫面檔重畫；畫布有程式沒有的三處一起做：清單分今天／本週／更早、完成面板三行預覽、第一次首頁的金鑰卡。分組有測試 `TranscriptListViewTests`。
- 為了 300 行拆出 `RecordingSheetView+Text`、`RecordingResultView+Status`、`TranscriptDetailView+Editing`、`SettingsView+KeyStatus`。
- CI 第三輪才綠（run 42367701089）；合進 main 81339ef，tag v0.1.7 → release run 42368080663 成功，**v0.1.7 build 8 上 TestFlight**。分支已刪。
- 切片帳本記組塊 U 與跳過紀錄；待驗清單加「v0.1.7 統一風格」那份，錄音不斷那份往下移、改在 0.1.7 做。

## 🚧 還沒做完 / 待決定

1. **米走介面**：清單三段（先看兩分鐘、錄一段短的、深色與大字）。要他的「我看到 ___」、對不上畫布的截圖、手機型號與 iOS 版本。只回「都 ok」要再問一次。
2. **錄音不斷（組塊 S 第一批）仍沒驗**：v0.1.6 被 0.1.7 蓋掉了，改在 0.1.7 驗，同一份清單下半。米回報錄音問題時，先分清楚是介面改壞還是錄音本身。
3. **真機沒人看過的介面風險**（我猜的，等米回報）：清單與設定的 `Form`／`List` 圓角跟系統走，不一定是 16；錄音面板半頁高度下，完成面板內容（預覽＋兩顆鈕＋通知那行）可能擠；`TextEditor` 的行距、`StatusStrip` 在鍵盤升起時的位置。
4. **第 0 步、第二批、第三批、Privacy Manifest**：照舊，見前一份 handoff 的第 3～8 條。第二批動手前 `TranscriptionQueue.swift` 型別 228 行、`OpenAIClient` 203、`MicrophoneCapture` 201，已經超過 200 的警告線（SwiftLint 只警告不擋）。

## 📌 關鍵決策（別再爭論）

- 統一風格四條：一頁一顆玉米黃；其他能按的一律金色（深色換玉米黃）；內容放白卡片、底是爆米花色；所有訊息用同一條狀態條。
- 錄音鈕快門式：金環 3、圓盤 184、實心麥克風 76，點擊範圍 220。「說」字和細線麥克風米都退過。
- 玉米插圖只出現在文字稿空清單（和之後的收成）。
- 米明知會蓋掉沒驗的 v0.1.6，仍選「現在就做進去」；介面先走，錄音後驗。
- 穩定性那邊的決定照舊（唯一目標是穩定性、自動接回、第三批 gpt-6-luna＋提示詞 v2.1、刪音檔等文字稿存好）。

## 📂 下個會話最重要的檔案

- `.vibe/操作清單-待驗.md` 最上面（米正在照這份走）
- `.vibe/切片帳本.md`「組塊 U」「組塊 S」「跳過紀錄」
- `.uiux/05-設計代號/使用規則.md`、`Tokens.swift`（改畫面前必讀）
- `ios-native/MiSay/App/`（共用元件與代號）、`ios-native/MiSay/Screens/`
- 畫布：https://claude.ai/artifact/S6UsLgtxX9FkFgkHSJXrwV ，要改先用 Artifact read 拿最新版；本機的畫布源檔在上一個會話的暫存區，已經不在了
- 前一份 handoff `handoff/archive/2026-11-07-2359-補六前.md`（穩定性那條線的全部細節）

## ⏭️ 下一步從哪繼續

1. 問米介面走完沒，把「我看到 ___」、截圖、手機型號、iOS 版本要齊。
2. 有對不上畫布的：改 `ios-native/MiSay/Screens/` 對應檔；數值要改就先改 `.uiux/05-設計代號/` 再抄到 App（使用規則第 9 條），重跑對比。改完本機先跑 `python .vibe/local/check_swift.py`（用 `.vibe/local/sf/` 的 SwiftFormat，會查行長、檔長），再開分支推 CI，綠了打 `v0.1.8`。注意：第三批原本排 v0.1.8，介面修正若先出版，第三批順延。
3. 介面沒問題：接著請米驗錄音不斷（清單下半），收診斷紀錄檔，照前一份 handoff 的第 2 步判斷。
4. 兩邊都過了，用 `vibe-spec-standards` 開第二批。

## 🗑️ 雜訊

- 這個會話沒用到 `.vibe/local/check_swift.py`，另外下載的 SwiftFormat Windows 版一跑就當（exit 139）、SwiftLint 缺 `sourcekitdInProc.dll`，所以 CI 多燒了兩輪。下次先用 `check_swift.py`。
- SwiftFormat 0.64 兩條會咬人的：單行閉包後面的修飾子要縮一層；只有一個頂層 view 的計算屬性不准掛 `@ViewBuilder`（contentBuilder 規則）。
- `.uiux/05-設計代號/` 的對比腳本 `domi-uiux-tokens/scripts/contrast.py` 這台機器找不到；對比表是同公式另寫的腳本算的，表上有註明。
- 畫布上的 Design 範本、比較板都收掉了，不用再找。
