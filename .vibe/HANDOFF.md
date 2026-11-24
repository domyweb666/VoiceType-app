# Handoff: 文字稿改照茄記不另外加密（規格定了、還沒寫）；widget 描述檔與 secret 都備好；fix-1125 沒合 main

> 產出時間：2026-11-25。worktree E:\VoiceType-words，分支 fix-1125（已推）。main 本機比 origin 多幾個 [交接] commit，沒推。
> 米今天的決定：引導與玉米動畫明確不要；穀倉移除；靈動島、鎖定畫面計時、控制中心按鈕要做；文字稿「照茄記，不另外加密」（取代當天稍早的「跟 iCloud 鑰匙圈走」）；secret「可以，設上去」。

## ✅ 完成
- main：片 Z1 改字自動認詞（CI 綠、沒出版）。v0.2.15 build 25 在 TestFlight 等米驗。
- fix-1125：四個小 bug（4620e1b，CI run 45444732707 綠，那次含鑰匙圈那包）＋錄音面板沒設金鑰的說法（46afa26）。鑰匙圈那包 601f327 已 revert。46afa26 與 revert 之後沒跑過 CI。
- widget 描述檔驗過（名稱、App ID、憑證跟主 App 同一張），已放簽章資料夾；GitHub secret `IOS_WIDGET_PROVISIONING_PROFILE_BASE64` 已設。

## 🚧 下一步一：文字稿不另外加密（在 fix-1125 上做）
茄記的做法：沒有自己的金鑰，內容存在 App 沙盒，靠 iOS。安全標準寫「不自己做加密；需要時用 iOS 原生」。規格：
1. `TranscriptStore.write` 直接寫 JSON，原子寫入與檔案保護（第一次解鎖後可用）照舊。
2. 讀：先當 JSON 解；解不開、而且不是 JSON 才用舊金鑰解密（只讀、不再產生新金鑰，`loadOrCreateKey` 換成 `read`）。
3. 舊檔自動換：`loadAll`、垃圾桶讀到加密檔，解開而且解得成 Transcript 之後，把解出來的原始 bytes 原子寫回同一個檔（不重新編碼，免得掉欄位）。寫失敗就留著加密的，下次再換。
4. **不能弄丟**：Keychain 讀失敗（還沒解鎖等，不是 notFound）時要丟 `keychainUnavailable`，不准把檔當壞檔搬走；只有 notFound 或解密失敗才照舊另存 Unreadable。舊金鑰留著不刪（刪除全部資料才刪，照舊）。
5. `RecordingTranscriptionJob` 進度檔同樣：寫 JSON，讀先 JSON 再舊金鑰。
6. 測試：舊加密檔讀得到而且檔案變成 JSON（測試裡自己用舊金鑰加密造檔）、換過之後把金鑰刪掉仍讀得到、垃圾桶與進度檔同樣、壞檔照舊另存、欄位不掉。改掉「在磁碟上不是明文」「垃圾桶的檔也加密」那兩條。
7. 文字：`BackupSection.newPhoneNote`（換新手機 iCloud 還原就帶得過去，沒有 iCloud 備份的用備份檔）、Backup、EraseAllDataSection、DraftVersion、TranscriptStore 檔頭註解；`.vibe/安全標準.md` 第二節那條 🔴 改寫並記米的決定與代價（沒加密的電腦備份讀得到；更新後不能退回舊版，舊版會把新檔搬去 Unreadable）。
8. 派沒參與的子代理審一次（重點：任何情況都不能讓現有文字稿不見）。`.vibe/審查-fix-1125.md` 的鑰匙圈那些條作廢；第 9 條已修，第 10 條（預覽開頭的連結露出網址，`PlainTextExport.opening`）順手修。
9. CI 綠之後問米要不要合 main。

## 🚧 下一步二：組塊 LA（帳本有規格）
LA1 空的 widget extension：App ID `org.domyweb.misay.widgets`、描述檔 `MiSay Widgets App Store`；改 `project.yml`、`ExportOptions.plist`、`ios-release.yml`。簽章只有打 tag 才驗得到，打 tag 要米同意。ControlWidget 最低版本動手前查官方。LA2 計時、LA3 控制中心。接在 fix-1125 後面開分支。

## 🚧 小尾巴
帳本與待驗清單補片 Z2（不另外加密）、Z3（四個 bug）；組塊 M 標「米 2026-11-25 明確不要」（分支 mascot-m1 沒刪）。穀倉殘留：`harvestTileInk`、`radiusTile`、「方塊-收成字」、`RecordingResultView` 收成註解，確認沒人用就拿掉。圖示與格式列滿版要 limrun 看。

## ❓ 等米決定
1. 合 main、出 TestFlight：都要米當次明講，`v*` tag 不准自己打。
2. 舊編輯框何時刪，等 v0.2.15 驗完。

## 知道但沒處理
認詞會漏：「Open AI→OpenAI」、多音字、三字名有時只收兩字。整理中把垃圾桶那篇永久刪掉會回清單。「刪除全部資料」後還開著的編輯頁再打字會存回來。`RecordingLauncher.append` 沒人用。
