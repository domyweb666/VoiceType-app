# Handoff: 文字稿不另外加密、組塊 LA 都合進 main；等米決定出 TestFlight

> 產出時間：2026-11-25。2026-11-25 米說「合進 main」，合併 commit 8e841c9 已推，main CI run 45464828994。

## ✅ 完成
- 分支 fix-1125（worktree `E:/VoiceType-words`，be52a41，已推）：片 Z2 文字稿不另外加密、片 Z3 四個小 bug、穀倉殘留清掉、CI 先等模擬器備好。獨立審查沒有高，3 中 5 低全修；修完那版沒再審第二次。5b358bb 的 CI 編譯、測試、SwiftLint 過，只紅在格式，be52a41 已修。
- 分支 live-activity（worktree `E:/VoiceType-la`，a198a05，已推，**含 fix-1125 全部**）：LA1 骨架與第二張描述檔、LA2 計時、LA3 控制中心。獨立審查 1 高 2 中 3 低，高與中改完（中的 OpenIntent 只能真機驗）。初版 2a89ef0 的 CI 綠。
- 帳本、待驗清單、PRD、架構藍圖、標準清單都更新了（main，本機 commit）。

## 🚧 下一步
1. CI 都綠（11-25 重跑）：fix-1125 run 45457025258，355 測試 0 失敗 1 略過；live-activity run 45457049293，373 測試 0 失敗 1 略過。
2. 已合 main（8e841c9）。main CI 綠（run 45464828994，373 測試 0 失敗 1 略過）。
3. 出 TestFlight 要米當次明講才打 `v*` tag。簽章鏈（第二張描述檔）只有打 tag 才驗得到。
4. 米驗 `操作清單-待驗.md` 最上面兩段。LA 最要看：鎖屏錄 15 分鐘有沒有變成「狀態沒更新」、控制中心按了有沒有真的開錄。

## 📌 決定（別再爭）
- 文字稿照茄記不另外加密；更新後不能退回舊版（再更新回來會自動搬回）。
- Live Activity 的任何失敗都不准影響錄音；不用 AudioRecordingIntent、不加 App Group。
- 引導與玉米火柴人、穀倉都不做。

## ❓ 等米
出 TestFlight；舊編輯框何時刪（等 v0.2.15 驗完）。

## 知道但沒處理
- 永久刪掉的篇若 Unreadable 還有一份會回清單一次；同 id 重複份讓橫幅一直算；垃圾桶部分讀不到沒提示。
- 控制中心若只開 App 不開錄：先換 `AppIntentsPackage`，再不行才 App Group（動 Apple 後台）。
- 認詞會漏：「Open AI→OpenAI」、多音字、三字名有時只收兩字。整理中把垃圾桶那篇永久刪掉會回清單。「刪除全部資料」後還開著的編輯頁再打字會存回來。`RecordingLauncher.append` 沒人用。
- 圖示與格式列滿版要 limrun 或真機看。專案根目錄有兩個 .whl 沒進 git，不知道誰放的。
