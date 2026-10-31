# Handoff: 組塊 A 建置上架整塊人驗通過（米說 0.1.2 已在 TestFlight），B1 金鑰 Keychain 人驗通過，下一片 B2 OpenAI 連線

> 產出時間：2026-11-01 02:20
> 前一會話的最後狀態，給下一個會話接續用。前一份（2026-10-31 06:50）在 `handoff/archive/`。

## ✅ 這次完成了什麼

- 切片：`.vibe/切片帳本.md`（7 組塊 32 片，H 範圍待米定、I 等方向測試）、`.vibe/組塊核准讀稿.md`。米放行 A、B、C。
- voice-lock：憲法焊進 `.vibe/規矩檔.md`「專案特定規矩」；`ios-native/.swiftformat`、`.swiftlint.yml`；`.vibe/hooks/pre-commit` 裝進 git（`core.hooksPath .vibe/hooks`，`.gitattributes` 鎖 LF）。實測擋金鑰、路徑、print、try!、空 catch、畫面寫死數值。
- **A1** walking skeleton：`ios-native/` XcodeGen 專案、空 App、`ios-native-ci.yml`（macos-26、XcodeGen 與 SwiftLint 釘版本＋SHA、SwiftFormat 預裝、ad-hoc 自簽模擬器版、iPhone 17）。米在 GitHub 驗過。
- **首頁線框重畫**：米否決 A／B／C，鎖定「正中央超大錄音鈕＋首頁只留待轉錄，清單搬到左上『文字稿』推入頁」。三方向 D／E／F 差在操作方式，線上版同一連結 https://claude.ai/artifact/JX7KMGTcDUNXnN9b4MjX9b 。流程結構樹、首次體驗文案、單手檢查表、閘門紀錄同步改。
- **A2** 首頁殼：`Screens/Home/HomeView.swift`（220pt 鈕、兩句文案、縮放回饋）、`Screens/Transcripts/`、`Screens/Settings/` 空頁；`Tokens.swift` 逐字抄入（源頭 `.uiux/05-設計代號/Tokens.swift` 只改排版＋加 `recordTap` 220）；`Assets.xcassets` 12 色淺／深；部署目標改 **iOS 17**（米定）。
- **B1** `APIKey/APIKeyStore.swift`：Keychain 存讀刪、trim、拒空、ThisDeviceOnly、Failure 只帶狀態碼；6 個中文名測試。CI 7 測試 0 失敗。
- **Apple 後台五步米親手辦完**（2026-11-01）：App ID、profile `MiSay App Store`、API 金鑰 `github-ci`（Key ID `95S932UJWS`；Issuer ID 在記憶檔）、App 條目「米說」（Apple ID 6829266183）、TestFlight 測試資訊。七月 CSR 的鑰匙對不上，重產 `apple-distribution-2026-11.key/.csr`，重辦憑證。**六個 iOS secret 全設好**（`gh secret list`）。簽章素材在本機簽章資料夾（位置在記憶檔 `voicetype-release-signing`；含 p12、密碼檔、.p8、.mobileprovision、.cer、私鑰，絕不進 repo）。
- **A3** `ios-release.yml` 重寫：tag `v*` 觸發、XcodeGen、匯入 p12、裝 profile、manual signing 封裝、匯出、`upload-testflight-build@v5.9.0`；版本從 tag、build 號用流水號；`ExportOptions.plist` 複製到 `ios-native/`；`ios/README-release.md` 更新。v0.1.0 被 Apple 退五條 ITMS（圖示、iPad 方向、啟動畫面、圖示名）→ 補暫代圖示、`TARGETED_DEVICE_FAMILY 1`、直向、`UILaunchScreen` → **v0.1.2 上 TestFlight，Apple VALID**。
- **組塊 A 整塊人驗通過**：米從 TestFlight 裝 0.1.2，回報黃鈕寫「說」、按了縮一下、文字稿推入空頁。人驗存檔點 `900c413`。
- 踩過的坑回灌規矩檔 8 條（runner 工具自帶、`///` 註解、掃 diff 對禁區、逗號互斥、模擬器 ad-hoc 簽章、測試只准模擬器跑、TestFlight 首次四樣前置、tag 不重用）。白話版在 `.vibe/踩坑紀錄.md`。
- 全部 push 到 `origin/main`，tag `v0.1.0`、`v0.1.1`（取消）、`v0.1.2`。

## 🚧 還沒做完 / 待決定

- **B2 OpenAI 連線核心**是下一片（`spec-standards` 開始）。B3 設定頁金鑰列之後。
- **走查閘米跳過四次**（A1、A2、B1、A3），都記在帳本「跳過紀錄」。B3 設定頁沒有米「貼金鑰那一刻期望什麼」的原話，ship-check 會要他認領。
- **米的驗收回報習慣是「都 ok」**，每次要追問一輪才拿到描述。A1、B1 是對照 AI 列的預期值後收下；組塊 A 米講了三句具體的。「黃色的底色」疑指鈕不是整個底，待截圖確認。
- **`desktop-release.yml` 也吃 `v*` tag**：每推 iOS tag 它也編一次 macOS（成功，沒壞事）。要不要把它改成別的 tag 前綴，米定；改它屬於凍結檔。
- **設計待定三件**（帳本 A2 段）：減少動態「底色加深」沒數值；SE 180pt 怎麼處理；鈕中心比線框低約 34pt。
- **首頁操作方式 D／E／F 等方向測試**（組塊 I）；「文字稿」清單推入頁線框還沒畫；單手檢查表七項仍全「待真機」。
- **組塊 H 範圍待米定**（通知、捷徑、匯入音檔、刪除全部資料等七項）。
- 暫代圖示是黃色實心方塊；正式圖示是上架片。
- App ID 的 App Group 與 iCloud container 值可能還沒在 Identifiers 頁指定（第一版用不到）。昨天 10/31 另一張沒鑰匙的「iPhone Distribution」孤兒憑證可撤銷。
- `.claude/settings.local.json` 的明文 GitHub token 這次沒碰，米沒回覆。
- 米的 iPhone 機型（最大、最小）仍沒問到。

## 📌 關鍵決策（這次定下來的，下次別再爭論）

- 首頁骨架米鎖定：正中央超大錄音鈕＋待轉錄；清單、搜尋、收成全搬出首頁。方向只剩 D／E／F 的操作方式差異。
- 部署目標 iOS 17（Tokens 的動畫與觸覺寫法需要）。
- 只給 iPhone、直向（`TARGETED_DEVICE_FAMILY 1`），Apple 退件後確定。
- CI 工具一律從官方 release 釘版本＋SHA，不信 runner 預裝；模擬器版 ad-hoc 自簽。
- 平行評估結論：不加速，單條 B1→B2→B3→C1（B 能靠 CI 驗到底，C 的麥克風要真機）。
- 規矩檔是唯一規矩源；pre-commit hook 與 CI 的 SwiftLint／SwiftFormat 是強制層；畫面只准用 `Token.*`。
- `APIKeyStore` 的 service／account、ThisDeviceOnly 不准改；單元測試只准模擬器跑。

## 📂 下個會話最重要的檔案

- `.vibe/HANDOFF.md` ← 就是這份
- `.vibe/規矩檔.md` ← 每次動工前必讀，含專案特定規矩與 8 條踩過的坑
- `.vibe/切片帳本.md` ← 真相源；「進行中」指向 B2
- `.vibe/標準清單.md` ← 現在是 A3 的，B2 要重寫
- `.vibe/黃金行為.md`、`.vibe/安全標準.md`（B2 要過第三節網路、第四節花費、第一節金鑰不進 log）
- `.vibe/架構藍圖.md`（M11 只被 M6 驗證、M3、M4 用；M11 用 M6）
- `ios-native/`：`project.yml`、`MiSay/APIKey/APIKeyStore.swift`（B2 要呼叫它讀金鑰）、`Screens/`
- `.github/workflows/ios-native-ci.yml`（日常）、`ios-release.yml`（tag 上 TestFlight）
- `ios/README-release.md`、記憶檔 `voicetype-release-signing.md`（簽章素材與識別碼）
- `.uiux/03-線框/方向說明.md`（米鎖定的骨架）、`.uiux/05-設計代號/Tokens.swift`（源頭）

## ⏭️ 下一步從哪繼續

1. 讀這份、`.vibe/規矩檔.md`、`.vibe/安全標準.md`。
2. 轉 `vibe-traffic-control`：`state.json` station 是 `spec-standards`，進行中是 B2 → `vibe-spec-standards` 為 B2 列標準。
3. B2 範圍（帳本）：`OpenAI/` 方塊 M11：帶金鑰送請求（只准 `https://api.openai.com`、ATS 不加例外）、逾時、回應分「可重試／不可重試」、錯誤不帶金鑰、一個「驗證金鑰」的呼叫；單元測試用假伺服器（`URLProtocol` 攔截，不裝套件）。寫程式前查證 OpenAI 的驗證端點（例如 `GET /v1/models`）與錯誤碼，不憑記憶。⚠️ 對外，立即驗。
4. 每片流程照舊：spec-standards → plan-readback → 實作 → 乾淨 subagent 自審 → push 看 CI → 示範分支（若有新規矩）→ 機器存檔點 → 立即驗或批次。
5. 推 tag 上 TestFlight 只在組塊到齊要給米裝的時候；下一個 tag 是 `v0.1.3`。

## 🗑️ 這次會話的雜訊（下次別重新討論）

- Flutter vs SwiftUI、分頁列、首頁 A／B／C 都已定，不重開。
- 米說「我怎麼裝到手機」問過三次，答案是 A3，現在已解；之後每個組塊到齊就推 tag。
- A1 審查員砍掉的七個 project.yml 鍵裡，四個後來因 Apple 退件加回（版本兩鍵、裝置家族、方向），這不是審查員錯，是當時沒要求。
- SwiftFormat 與 SwiftLint 版本：runner 預裝 SwiftFormat 0.64.3；SwiftLint 沒預裝，釘 0.65.1 下載。
