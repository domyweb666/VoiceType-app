# 米說 iOS 上架設定

這條管線的目標是：推一個 `v*` tag，GitHub 的 macOS runner 就把 App 編譯、簽章、送到 TestFlight。
開發機是 Windows，沒有 Xcode，所以 iOS 的每一次編譯都只能走這條 CI。

## 現在的狀態

CI 檔案 `.github/workflows/ios-release.yml` 已經寫好，但現在推 tag 會在第二個步驟就失敗，
因為簽章用的六個 GitHub secret 一個都還沒設：

| secret | 內容 |
|---|---|
| `IOS_DIST_CERT_BASE64` | Apple Distribution 憑證（p12 轉 base64） |
| `IOS_DIST_CERT_PASSWORD` | 上面那包 p12 的密碼 |
| `IOS_PROVISIONING_PROFILE_BASE64` | App Store provisioning profile 轉 base64 |
| `ASC_ISSUER_ID` | App Store Connect API 的 Issuer ID |
| `ASC_KEY_ID` | App Store Connect API 的 Key ID |
| `ASC_API_PRIVATE_KEY` | App Store Connect API 的 `.p8` 私鑰內容 |

倉庫裡另外那六個 `APPLE_*` secret 是桌面版 macOS 公證用的（`desktop-release.yml`），
名字很像但這裡完全用不到。Developer ID Application 憑證簽不了 iOS。

## 專案裡已經對齊的值

辦 Apple 後台的時候照這張表填，一個字都不要差：

| 項目 | 值 | 寫在哪 |
|---|---|---|
| Bundle ID | `org.domyweb.misay` | `ios/Runner.xcodeproj/project.pbxproj`、`ios/ExportOptions.plist` |
| Team ID | `3ZT74P4WM2` | `ios/ExportOptions.plist` |
| Provisioning profile 名稱 | `MiSay App Store` | 同上兩個檔案 |
| 最低 iOS 版本 | 16.0 | `project.pbxproj` |
| App Group | `group.org.domyweb.misay` | 還沒用到，第 4 階段的錄音小工具要 |
| iCloud container | `iCloud.org.domyweb.misay` | 還沒用到，第 5 階段的同步要 |

profile 名稱寫死在專案裡，取錯名字 CI 會找不到 profile。

## 要親手辦的五步

全部在 Apple 的網站上做，用這個專案的 Apple 開發者帳號登入。
辦好的檔案丟回本機的簽章素材資料夾（位置問 Claude，不寫進這份公開文件）。

### 1. 換 Apple Distribution 憑證

開 <https://developer.apple.com/account/resources/certificates/add>

選 **Apple Distribution**。不要選 Developer ID Application，那張是桌面版在用的。
上傳簽章資料夾裡的 `apple-distribution-request.csr`，下載回來的 `.cer` 丟回同一個資料夾。

### 2. 註冊 App ID，並且把 capability 一次勾完

開 <https://developer.apple.com/account/resources/identifiers/add/bundleId>

選 App IDs → App。Description 填 `MiSay`，Bundle ID 選 **Explicit**，填 `org.domyweb.misay`。

Capabilities 這次要勾三個，不要跳過：

- **App Groups** —— 之後控制中心的錄音鍵要跟 App 共用資料
- **iCloud**（勾 iCloud Documents）—— 文字稿同步到你自己的 iCloud
- **App Attest** —— 伺服器用來確認請求真的來自這個 App

這三個現在用不到，但 capability 是在 App ID 上開的，profile 必須在開完之後才產生。
現在跳過，之後做到那些功能時整套憑證和 profile 都要重辦一輪。

勾 App Groups 和 iCloud 的時候它會要你指定群組和容器，按旁邊的 Edit 新建：

- App Group 填 `group.org.domyweb.misay`
- iCloud container 填 `iCloud.org.domyweb.misay`

### 3. 建 Provisioning Profile

開 <https://developer.apple.com/account/resources/profiles/add>

在 Distribution 那一區選 **App Store Connect**。
App ID 選 `org.domyweb.misay`，憑證選第 1 步辦的那張 Apple Distribution。

名稱填 `MiSay App Store`，含空格、大小寫一字不差。

下載 `.mobileprovision`，丟回簽章資料夾。

### 4. 建 App Store Connect API 金鑰

開 <https://appstoreconnect.apple.com> → 使用者與存取 → 整合 → App Store Connect API → 團隊金鑰

按「+」新增，名稱 `github-ci`，權限選 **App 管理**。

下載 `.p8`。**這個檔案只能下載一次**，關掉頁面就再也拿不到，弄丟只能重辦一把。
丟回簽章資料夾，另外抄下兩個值：金鑰列上的 **Key ID**，以及頁面上方的 **Issuer ID**。

### 5. 在 App Store Connect 建 App 條目

開 <https://appstoreconnect.apple.com> → 我的 App → 「+」→ 新增 App

- 平台選 iOS
- 名稱填 `米說`。這個名字全球唯一，被佔的話換一個（例如「米說 語音轉文字」），
  商店顯示名之後還能改，不影響 CI
- 主要語言選繁體中文
- Bundle ID 選 `org.domyweb.misay`
- SKU 填 `misay`

## 辦完之後 Claude 接手

1. 用簽章資料夾裡的私鑰加第 1 步的 `.cer` 合成 p12，轉 base64
2. 設上面那六個 GitHub secret
3. 推一個 `v*` tag 觸發 workflow，確認 App Store Connect 收到建置

跟 Claude 說一聲就好，不用自己弄 base64。

## 每次發版要注意

`CFBundleVersion` 是跟著 `pubspec.yaml` 的 build number 走的（`version: 1.0.0+1` 的 `+1`）。
App Store Connect 不收重複的 build number，所以**每次推 tag 前都要把 `+1` 往上加**，
否則編譯會成功、上傳會被退。

## 之後還會再來一輪

第 4 階段要做控制中心和鎖定畫面的錄音鍵，那是一個獨立的 Widget Extension，
需要它自己的 App ID（`org.domyweb.misay.RecordWidget`）和它自己的 provisioning profile。
到時候會再請你跑一次第 2、3 步。

## 送審前還缺的素材

- iPhone 截圖，至少 6.9 吋一組
- App 描述、關鍵字、支援網址
- 隱私權政策網址，必填。收語音的 App 一定會被仔細看
- App 隱私問卷：有收音訊、透過第三方 API 轉錄，照實填
- 出口合規：只用 HTTPS 的話選 exempt
