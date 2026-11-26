<!-- overnight: done -->
# Overnight 報告
## 早上摘要
五項都做完了，每項都有測試，CI 全綠（最後一次 45754860439：439 個測試，0 失敗，1 略過）。都在分支 `overnight-20261126-1105`，還沒合進 main，也沒出 TestFlight。

1. 刪除全部資料後，還開著的編輯頁打字不會再把刪掉的篇存回去。改在 `Storage/TranscriptStore+Erase.swift`（新檔）、`EraseAllDataSection.swift`、`TranscriptDetailView` 三個檔。舊頁會出現「存不進去」，頁面不會自己關。
2. 垃圾桶三件：永久刪掉的讀不到篇不會再回清單；同一篇重複份只算一次，橫幅不會一直在；垃圾桶有讀不到的篇時，最上面多一句灰字。改在 `TranscriptStore+Unreadable.swift`、`+Trash.swift`、`TrashView.swift`。
3. 認詞：「Open AI」改「OpenAI」認得了；曾、單、解這類姓氏多音字算讀音像；三字人名在斷詞拆成單字時會連姓收。改在 `Learning/EditDiff.swift`、`SoundAlike.swift`、`CorrectedWords.swift`。
4. 拿掉沒人用的 `RecordingLauncher` 接著錄請求，連帶首頁兩個只在那裡用到的變數。
5. 長稿「AI 改了什麼」：超過 2 萬字也比得出來，上限放到 12 萬字。2 萬字以內結果跟以前一模一樣。新檔 `Polishing/ChunkedDifference.swift`。

要你決定的事在下面「待確認」，最要緊的是第一條：永久刪除時會連另存的壞檔一起刪，刪了救不回。

早上建議先測：
- 設定 → 進階 → 刪除全部資料，刪之前先開著一篇，刪完回那篇打幾個字，再看清單有沒有東西跑回來。
- 垃圾桶畫面那句灰字（要有讀不到的篇才會出現，平常看不到）。
- 拿一篇很長的稿打開「AI 改了什麼」，看順不順。
- 在一篇稿裡把「Open AI」改成「OpenAI」，看詞庫有沒有收。

這些要出新版才能在手機上測。要出 TestFlight 跟我說一聲。

另外，專案外面多了一個 0 位元組空檔 `E:\c_tmp_ed5.py`，是夜裡打錯指令留下的，我沒權限刪，要請你刪掉。

合併（在 E:\VoiceType-overnight 裡快轉推上 main）：`git -C E:\VoiceType-overnight push origin HEAD:main`
丟棄：`git worktree remove E:\VoiceType-overnight; git branch -D overnight-20261126-1105; git push origin --delete overnight-20261126-1105`

## 任務清單
- [x] 1. 「刪除全部資料」後還開著的編輯頁再打字不會存回來｜完成：有單元測試證明刪除後的寫入被擋、CI 綠
- [x] 2. 垃圾桶三個小毛病：永久刪掉的篇若讀不到不再回清單；同 id 重複份不讓橫幅一直算；垃圾桶部分讀不到時有一句提示｜完成：各有測試、CI 綠
- [x] 3. 認詞補漏：「Open AI→OpenAI」這類空格拆開的英文詞、多音字、三字名｜完成：對應測試案例過、CI 綠（做不到的寫原因）｜三類都補了；多音字只補姓氏地名 13 字、三字名只補「斷詞拆成單字」那種，剩下的寫在待確認
- [x] 4. 移除沒人呼叫的 `RecordingLauncher.append`｜完成：全專案搜不到呼叫、CI 綠｜首頁只在這裡被設的 appendTarget／appendInsertion 一起拿掉；面板的 appendingTo／insertingAt 文字稿頁還在用，留著
- [x] 5. 性能 H1 第 2 步：長稿分段比對（不動資料格式）｜完成：一小時稿長度的測試比得出結果、短稿結果跟原本一樣、CI 綠｜用錨點分段，不用段落切（理由見待確認）

## 不做（要米決定或等真機）
- H2 第 2、3 步（動資料格式）、清單工具列收「⋯」、打 tag 出 TestFlight、刪未追蹤檔、跑真音檔量測

## 待確認（需要多米決定的事）
- 第 2 項：垃圾桶「立刻刪除」或放滿 30 天自動刪時，清單也沒有這篇的話，Unreadable/ 裡同一篇的另存檔（含解不開的）會一起刪。這是讓刪掉的不再回來的唯一做法（不加新資料檔），但另存檔從此救不回。米要保留另存檔就說，改回只刪垃圾桶那份。
- 第 2 項：垃圾桶的提示句「有 N 篇讀不到，沒列在這裡。」放在列表最上面、灰色小字，要看畫面。
- 第 3 項：多音字只列了姓氏、地名常用另一個讀音的 13 個字（曾、單、解、仇、區、查、沈、翟、朴、樸、尉、繆、廈）。重、行、調、樂這類一般詞也常用的多音字沒列，因為列了會讓「從新→重新」這種一般錯字也被收進詞彙。米要補哪些字可以直接加。
- 第 3 項：三字名只在斷詞把名字拆成單字、左邊是台灣前三十大姓時才連姓收。還會漏兩種：斷詞把後兩字當成一個詞（陳／炳彰，跟「這張／蘋果」分不出來，硬收會變「張蘋果」）、斷詞把姓和第一個字併成一個詞而只改第三個字（陳炳／彰）。要再補得靠人名辨識或詞典，屬於大改，先不做。
- 第 3 項：「Open AI→OpenAI」只認英文字母之間的空白拿掉、改後有大寫的；「can not→cannot」這種沒大寫的照舊不收。反過來把 OpenAI 拆成 Open AI 不收。
- 第 5 項：分段比不是照段落或句號切，是找兩邊都只出現一次的 6 個字當錨點、錨點之間才逐字比。口語稿常常整篇沒換行、潤飾又會改標點，照句子切兩邊幾乎對不上。新加一個檔 `Polishing/ChunkedDifference.swift`（PolishDiff 和 MeaningAlignment 共用，規矩檔說新型別要先問，夜裡沒人問，先做）。米不要多一個檔就說，可以併回 PolishDiff。
- 第 5 項：「這篇太長，手機比不動」的上限從 2 萬字放到 12 萬字（兩邊加起來，一邊約 6 萬字、四小時上下）。改得很兇、錨點找不到的那幾段會整段標成刪掉＋加上，不會逐字標。真機上一小時稿打開「AI 改了什麼」順不順、會不會頓，要米看。

## 卡住的項目

## 執行紀錄
- 11:05 開分支 overnight-20261126-1105（worktree E:\VoiceType-overnight，從 origin/main 2ee5d25）。共用資料夾 E:\VoiceType 留在 main 不動。
- 11:30 第 1 項完成（ded1dde）：新增 ios-native/MiSay/Storage/TranscriptStore+Erase.swift（記憶體裡的抹除代數＋save(_:openedInGeneration:)）；改 EraseAllDataSection.swift（刪光前先遞增）、TranscriptDetailView.swift（開頁記代數）、+Editing.swift（改字自動存帶代數）、+Leaving.swift（放回空白新文稿帶代數）；EraseAllDataTests 加兩個測試。CI 45747050928 綠，兩個新測試都 passed。
- 11:55 第 2 項完成（b98f9d2）：改 ios-native/MiSay/Storage/TranscriptStore+Unreadable.swift（讀不到的篇數同一篇只算一次、清單或垃圾桶已有的不算；新增 removeSetAside）、TranscriptStore+Trash.swift（deleteFromTrash 哪裡都沒有了才連另存的一起刪；新增 unlistedTrashCount）、Screens/Transcripts/TrashView.swift（有讀不到的才出現一句）；新增 MiSayTests/SetAsideTrashTests.swift 五個測試，BlockedTranscriptTests 兩個重複份計數改 0。CI 45750086386 綠（428 測試、0 失敗、1 略過），新測試都 passed。
- 12:10 第 3 項完成（3bad85a）：改 ios-native/MiSay/Learning/EditDiff.swift（拼回拆開的英文詞算改用詞）、SoundAlike.swift（姓氏地名多音字表）、CorrectedWords.swift（三字名連姓）；CorrectedWordsTests 加六個測試。CI 45752440293 綠（434 測試、0 失敗、1 略過），六個新測試都 passed。
- 12:15 第 4 項完成（674c5e9）：改 ios-native/MiSay/App/RecordingLauncher.swift（拿掉 Request.append，註解改 K1）、Screens/Home/HomeView.swift（拿掉 appendTarget／appendInsertion 與接收那段）、Screens/Root/RootTabView.swift（註解）。CI 45753922851 綠（434 測試、0 失敗、1 略過）。
- 12:30 第 5 項完成（d51bc90）：新增 ios-native/MiSay/Polishing/ChunkedDifference.swift；改 PolishDiff.swift（改用分段比、上限 12 萬）、MeaningAlignment.swift（改用分段比）；新增 MiSayTests/ChunkedDifferenceTests.swift 五個測試。CI 45754860439 綠（439 測試、0 失敗、1 略過），五個新測試都 passed。
- 12:40 寫早上摘要，整晚模式收工。
