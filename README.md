# VoiceType

**語音變文字，說完就整理好。**

VoiceType 是一款開源的語音轉文字工具，讓你用「說」的方式快速產出結構化筆記。錄音完畢後，AI 自動轉錄並潤飾成適合閱讀的文字 — 不改你的語氣、不加多餘標題，只去掉贅字、修好斷句。

> 取代 Otter.ai、訊飛等訂閱制語音筆記服務。你自己的 API Key，資料不經第三方伺服器，不綁月費。

<!-- 截圖預留區 — 歡迎提交 PR 補圖
![VoiceType 截圖](docs/screenshot.png)
-->

---

## 這個專案能幫你什麼？

你可能遇過這些情境：

- 開會 / 上課想記錄，但打字跟不上說話速度
- 靈感來了想記下來，打開手機打字太慢
- 錄了一大段語音備忘，但回頭聽完全不想整理

**VoiceType 的做法：**

1. 按一下錄音，想講多久就講多久（20、30 分鐘都沒問題）
2. 停止錄音後，自動送到 OpenAI Whisper 轉成逐字稿
3. 一鍵「潤飾」— AI 幫你去掉「呃」「那個」「然後」等贅字，修好斷句，但保留你的語氣風格
4. 匯出成 TXT / Markdown / ZIP，分享到任何地方

**結果：你花 5 分鐘說話，就得到一篇整理好的文字筆記。**

---

## 功能亮點

**AI 語音轉文字** — 使用 OpenAI Whisper (`gpt-4o-mini-transcribe`)，支援繁體中文，長錄音自動切段處理

**智慧潤飾** — GPT-4o-mini 以「最小化干預」原則修稿：刪贅字、修斷句、加標點，不改你的風格

**上下文銜接** — 每段轉錄自動帶入前段結尾作為提示，多段錄音語意不斷裂

**自訂詞彙表** — 加入專業術語（如「臺積電」「TSMC」），確保 AI 正確辨識你的領域用語

**錄音日曆 + 熱力圖** — 類似 GitHub 貢獻圖，追蹤你的錄音習慣，顯示連續天數

**桌面快捷鍵** — Windows 上 `Ctrl+Alt+V` 全域快捷鍵切換錄音，最小化到系統匣，不用切換視窗

**本地優先** — 所有轉錄記錄存在本機（Hive 資料庫），API Key 存在系統安全儲存區，開發者看不到你的資料

**費用透明** — 每次轉錄後顯示預估花費（新台幣），讓你清楚知道用了多少

---

## 快速開始

### 前置需求

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.11.4 以上
- OpenAI API Key（[取得方式](https://platform.openai.com/api-keys)）
- 各平台建置工具（見下方「建置指南」）

### 安裝與執行

```bash
# 1. 取得原始碼
git clone https://github.com/domyweb666/VoiceType.git
cd VoiceType

# 2. 安裝相依套件
flutter pub get

# 3. 執行（以 Windows 為例）
flutter run -d windows
```

### 設定 API Key

1. 開啟 VoiceType 應用程式
2. 點擊右上角齒輪圖示進入「設定」
3. 在「OpenAI API Key」欄位貼上你的金鑰
4. 金鑰會儲存在系統安全儲存區（Windows Credential Manager / iOS Keychain / Android Keystore）

---

## 軟體操作教學

### 第一步：錄音

- 點擊畫面中央的大圓形錄音按鈕開始錄音
- 錄音中會顯示即時音量波形和計時器
- 再次點擊停止錄音
- **Windows 快捷鍵：** `Ctrl+Alt+V` 可在任何視窗下切換錄音

### 第二步：自動轉錄

- 停止錄音後，系統自動開始轉錄
- 長錄音（超過 10 分鐘）會自動切成多段處理
- 轉錄過程中會逐段顯示進度，例如「轉錄第 2/5 段」
- 完成後顯示完整的口語逐字稿

### 第三步：一鍵潤飾

- 點擊「潤飾文字稿」按鈕
- AI 會以最小干預原則處理你的文字：
  - 刪除贅字（呃、那個、然後、就是說...）
  - 修正過長的斷句
  - 加上正確標點
  - **不會**改變你的語氣、加標題、或改成公文體
- 潤飾後的文字和原始口語稿都會保留，隨時可對照

### 第四步：管理與匯出

- **歷史記錄：** 所有錄音自動儲存，可依日期篩選（今天 / 本週 / 本月）或搜尋關鍵字
- **編輯：** 潤飾後的文字可直接在 App 內修改
- **重新潤飾：** 可調整提示詞後重新產生潤飾版本
- **匯出格式：**
  - `.txt` — 純文字
  - `.md` — Markdown 格式（含標題、分段）
  - `.zip` — 批次匯出所有記錄
- 透過系統分享功能傳送到 Email、LINE、雲端硬碟等

### 進階功能

- **自訂詞彙表：** 在設定中加入你常用的專業術語，AI 轉錄時會優先使用
- **自訂潤飾提示詞：** 在設定中修改 AI 潤飾的行為指引
- **文字大小：** 四段可調（0.9x / 1.0x / 1.15x / 1.3x）
- **錄音日曆：** 查看錄音熱力圖、連續錄音天數統計

---

## 支援平台

| 平台 | 狀態 | 特色功能 |
|------|------|----------|
| **Windows** | 主要開發平台 | 系統匣、全域快捷鍵 `Ctrl+Alt+V`、最小化到匣 |
| **Android** | 完整支援 | 麥克風權限、主畫面 Widget |
| **macOS** | 支援 | 系統匣、快捷鍵（需在 Mac 上建置） |
| **iOS** | 支援 | 麥克風權限（需在 Mac 上建置） |
| **Linux** | 支援 | 系統匣、快捷鍵 |
| **Web** | 基礎支援 | 透過瀏覽器麥克風 API |

---

## 費用估算

VoiceType 本身免費，但轉錄和潤飾使用 OpenAI API，會產生少量費用：

| 錄音長度 | 預估花費（新台幣） |
|----------|-------------------|
| 10 分鐘 | 約 NT$1 |
| 20 分鐘 | 約 NT$2 |
| 30 分鐘 | 約 NT$3 |

> 以上為概估，實際費用取決於 OpenAI 定價和語音內容複雜度。
> 相比月費制服務（Otter.ai ~US$17/月），只在用的時候才花錢，長期更省。

---

## 隱私與安全

- **本地儲存** — 所有轉錄記錄存在你的裝置上（Hive 本地資料庫），不上傳到任何第三方伺服器
- **安全金鑰管理** — API Key 使用平台原生安全儲存（Windows Credential Manager / iOS Keychain / Android Keystore）
- **無遙測** — 應用程式不會收集使用數據或分析資訊
- **音訊處理** — 錄音檔僅傳送到 OpenAI API 進行轉錄，不經過開發者伺服器

> 注意：音訊會上傳到 OpenAI 進行轉錄處理，請參閱 [OpenAI 使用條款](https://openai.com/policies/terms-of-use)。

---

## 建置指南

### Windows

```bash
flutter build windows --release
# 產物位置：build/windows/x64/runner/Release/
```

### Android APK

```bash
# 需安裝 Android Studio 並設定好 Android SDK
flutter build apk --release
# 產物位置：build/app/outputs/flutter-apk/app-release.apk
```

### macOS（需在 Mac 上執行）

```bash
flutter build macos --release
# 產物位置：build/macos/Build/Products/Release/voicetype.app
```

### iOS（需在 Mac 上執行）

```bash
flutter build ios --release --no-codesign
# 產物位置：build/ios/iphoneos/Runner.app
# 上架 App Store 需要 Apple Developer 帳號和正式簽名
```

---

## 技術架構

| 層級 | 技術 |
|------|------|
| 框架 | Flutter 3.11+ / Dart |
| 狀態管理 | Provider |
| 本地資料庫 | Hive |
| 安全儲存 | flutter_secure_storage |
| HTTP 客戶端 | Dio（含指數退避重試） |
| 語音錄製 | record (PCM 16kHz/16bit/mono) |
| 桌面整合 | window_manager + tray_manager + hotkey_manager |
| AI 轉錄 | OpenAI Whisper (gpt-4o-mini-transcribe) |
| AI 潤飾 | OpenAI GPT-4o-mini |

---

## 授權

本專案採用 [Business Source License 1.1](LICENSE)。

**你可以：**
- 個人使用、學習、研究
- 修改原始碼
- 非商業用途分發

**不可以：**
- 用於商業競品或 SaaS 服務

2030 年 4 月 13 日後，本專案將自動轉為 Apache License 2.0。

---

## 貢獻

歡迎提交 Issue 和 Pull Request！

---

## Star History

如果這個專案對你有幫助，請給個 Star 支持一下！

<!-- 取得 GitHub URL 後替換 domyweb666
[![Star History Chart](https://api.star-history.com/svg?repos=domyweb666/VoiceType&type=Date)](https://star-history.com/#domyweb666/VoiceType&Date)
-->
