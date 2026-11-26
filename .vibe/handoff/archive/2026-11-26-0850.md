# Handoff: 芹查 QC-0014 七筆處理完、性能檢查先改三處，都在 main、CI 綠，還沒出版

> 產出時間：2026-11-26 08:50
> 接在 main 4f526aa（已推）。最新 CI run 45730348705 綠（421 測試 0 失敗 1 略過）。

## ✅ 這次完成了什麼
- 芹查 QC-0014（玉米說第 1 場 7 筆）：
  - #108 分頁列太低 → 米選「改成自畫膠囊」：`Screens/Root/FloatingTabBar.swift`（domy 300×64、離安全區底 12），`RootTabView` 藏系統列、鍵盤出來就收、每頁墊 `Token.Shape.tabClearance`。
  - #109、#110 設定頁、進階頁說明拿掉（備份、刪除全部只在出狀況時講一句）。
  - #111 清單太擠 → 畫三版設計稿 https://claude.ai/artifact/WybsCGeVnscs6bs2EGjefq ，米選 A「清爽列表」，已做進 `TranscriptListView`、`+Organize`（沒卡片沒箭頭、右邊短日期、第一句當粗體行）。右上工具列沒照設計稿收成「⋯」。
  - #112 鍵盤上方那一排：中間直線、右邊兩鈕放淡金膠囊。
  - #113 只回答（「這趟講了幾件事」是拆篇），沒改程式。
  - #114「AI 改了什麼」不解釋：沒找到可能改了意思整塊不出現，刪加字數那句拿掉。
- 性能檢查（另開工作階段做的報告 `.vibe/性能檢查-2026-11-26.md`，3 高 5 中 6 低），米說「先改這三處」：H1 比對上限 6 萬→2 萬字；H2 去掉四處重複 `loadAll`；H3 清單搜尋一次重畫只算一次。報告最後有「已改」段。

## 🚧 還沒做完 / 待決定
- 出 TestFlight：要米當次明講（見記憶 testflight-needs-consent）。這次所有改動都還沒上手機。
- 真機驗：`.vibe/操作清單-待驗.md` 最上面「芹查 QC-0014」段（分頁列被不被鍵盤推、推進去的頁有沒有藏乾淨系統列、清單 A 擠不擠）。v0.2.16、v0.2.17 的段也還在等。
- 性能報告剩下的：H1 第 2 步（分段比，讓長稿也比得動）、M4（錄音面板每秒重畫 20 次，跟長錄耗電有關）、H2 第 2、3 步（版本搬出主檔、清單摘要快取，動資料格式，要米決定）。報告「建議的順序」第 4 條建議先在真機量。
- 清單右上工具列要不要照設計稿 A 收成「⋯」：等米看真機。
- 搜尋防抖動沒做（會改打字手感）。

## 📌 關鍵決策（別再爭）
- 分頁列改自畫膠囊（米 2026-11-26），推翻 11-14「分頁列留原生」。
- 清單照設計稿 A（米 2026-11-26）。
- 設定、進階、AI 改了什麼：不要說明文字，米不喜歡一堆說明。只留出狀況時的一句。
- 上一份交接的決定照舊：文字稿不另外加密；Live Activity 失敗不准影響錄音；引導、玉米火柴人、穀倉不做；jtbd-345 本機分支不要再推再合。

## 📂 下個會話最重要的檔案
- `.vibe/操作清單-待驗.md`（最上面三段）
- `.vibe/性能檢查-2026-11-26.md`
- `ios-native/MiSay/Screens/Root/RootTabView.swift`、`FloatingTabBar.swift`
- `ios-native/MiSay/Screens/Transcripts/TranscriptListView.swift`、`+Organize.swift`、`+Filter.swift`

## ⏭️ 下一步從哪繼續
1. 問米要不要「出 TestFlight」（v0.2.18）；米明講才打 tag。
2. 米回真機結果後，照操作清單逐條修；分頁列若被鍵盤推或推進去的頁還看到系統列，先查 `RootTabView` 的 `TabPageChrome`。
3. 米沒有新回報時，可提性能報告的 M4 或 H1 第 2 步，等米選。

## 🧩 剩下的工作（工作包）
- [ ] A：出 v0.2.18 到 TestFlight｜release run 綠｜tag｜等米明講
- [ ] B：性能 M4 錄音計時拆成小 view｜錄音面板只有計時那塊每秒重畫｜`Screens/Recording/*`｜等米選
- [ ] C：性能 H1 第 2 步分段比｜一小時稿比得動、記憶體跟最大段有關｜`Polishing/PolishDiff.swift`、`MeaningAlignment.swift`｜等米選

## 知道但沒處理（沿用上一份）
- 永久刪掉的篇若 Unreadable 還有一份會回清單一次；同 id 重複份讓橫幅一直算；垃圾桶部分讀不到沒提示。
- 認詞會漏「Open AI→OpenAI」、多音字、三字名。「刪除全部資料」後還開著的編輯頁再打字會存回來。`RecordingLauncher.append` 沒人用。
- 專案根目錄兩個 .whl、`.uiux/04-手感/玉米火柴人動作庫.html`、`.vibe/引導與動畫提案.md` 沒進 git，不知道要不要留（玉米火柴人米說不做）。
- 米的真音檔量測（`python .vibe/local/keywords_check.py 音檔 --yes`）還沒跑。

## 🗑️ 雜訊（別再討論）
- 前兩輪 CI 失敗只是 SwiftFormat 的 wrapPropertyBodies（單行屬性要換行），已修。
- 設定頁「讀兩次」其實是設定頁和進階頁各一次，不是重複。
