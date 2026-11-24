# Handoff: 分支 fix-1125（4620e1b）：金鑰跟 iCloud 鑰匙圈走＋四個小 bug 都已提交推上，審查回來 1 高 3 中要修、CI 要重跑、沒合 main

> 產出時間：2026-11-25。worktree E:\VoiceType-words，分支 fix-1125（從 main d94913e 開）。context 過 400K 交接。
> 米今天的話：「聚光燈引導和玉米火柴人動畫。這明確不要」「加密金鑰要不要跟 iCloud 鑰匙圈走：好」「這些幫我修復bug」（下面四個）。

## ✅ 完成
- main：片 Z1 改字自動認詞（CI 綠、沒出版）。組塊 Y v0.2.15 build 25 在 TestFlight 等米驗。
- fix-1125 已提交並推：金鑰。`TranscriptEncryptionKeyStore`（本機主金鑰 data-key 照舊；其他把與鑰匙圈用 data-key.<指紋>）、`TranscriptStore+Keys.swift`（打不開試別把、Unreadable 放回）、`ICloudKeyTests`、安全標準、備份頁那句話。設計重點寫在檔頭。

## 🚧 還沒
0. **先做這個**：`.vibe/審查-fix-1125.md` 的 1 高 3 中（低的也順手收），修完 CI 綠才問米合 main。下面 1、2 講的審查已經回來，不用重派；修完再派一次只看修正。
1. 四個 bug 已提交（4620e1b），差異讀過。CI run 45444732707（含金鑰）結果沒看；獨立審查（金鑰＋四個 bug）子代理在舊對話跑，結果若沒帶到就重派。圖示（t.square、number、number.square）與格式列滿版只能看模擬器。
2. 金鑰那個 commit：CI 結果沒看（「runner not acquired」是 GitHub 沒機器，rerun 就好）。**沒有獨立審查**。審查重點：任何情況都不能讓現有文字稿解不開；兩台手機各有一把；刪除全部資料；鑰匙圈讀取失敗時不能誤產新金鑰；模擬器的 Keychain 測得到 synchronizable 嗎；`restoreSetAside` 會不會蓋檔。
3. 帳本、待驗清單還沒寫：片 Z2 金鑰、Z3 四個 bug；組塊 M（mascot-m1，引導與玉米動畫）標「米 2026-11-25 明確不要」，分支沒刪（要刪先問）。組塊 Y「等米決定」的金鑰那條改成已定。

## ❓ 等米決定
1. 合進 main、出 TestFlight：都要米當次明講，`v*` tag 不准自己打。
2. 靈動島／控制中心、穀倉要不要做（2026-11-25 米問是什麼，已在對話解釋，等回）。
3. 舊編輯框何時刪，等 v0.2.15 驗完。

## 知道但沒處理
- 兩支手機實際搬家（iCloud 還原＋鑰匙圈）只有真機驗得到。OpenAI 金鑰照舊不跟鑰匙圈走。
- 認詞會漏：「Open AI→OpenAI」、多音字、三字名有時只收兩字。
- 整理中把垃圾桶那篇永久刪掉，整理完仍會回清單。「刪除全部資料」後還開著的編輯頁再打字會把那篇存回來。
- `RecordingLauncher.append` 沒人用了。單顆 * 夾中文不當記號。串文「1/」編號留在字裡。

## ⏭️ 下一步
看 CI 與審查結果 → 修 → 再綠 → 帳本與待驗清單 → 問米要不要合 main。
