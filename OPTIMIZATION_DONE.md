# VoiceType 優化執行紀錄

分支 `optimization-pass`。起點 commit `a90a7c4`（checkpoint），往後每一項都分開提交，可單獨 diff／回滾。全程 `flutter analyze` 保持 `No issues found`。

## 已完成（依 commit）

| Commit | 內容 |
|--------|------|
| `8f4fcc2` | Hive 歷史 at-rest 加密 + 防當機遷移；匯出暫存檔 try/finally 刪除；secure storage 讀取失敗降級為「未設 key」 |
| `7f091cb` | 修錄音通知 id 4711 撞號：改由 native 前景服務獨佔，Dart 走 MethodChannel 傳 elapsed |
| `86c7615` | release keystore 簽章骨架 + R8/resource shrink；App 名稱統一 VoiceType；launcher-icons 設定 |
| `fe2187d` | 波形 ring buffer、getter 快取、WAV 切割移到背景 isolate、OpenAI 回應格式驗證 |
| `40da99a` | 歷史清單改 ListView.builder + 搜尋 debounce；字級 snap；a11y；刪死碼 record_calendar_screen（697 行） |
| `9b65100` | 拆 home_screen（2077 → 621 行）→ lib/widgets/home/ 五檔；修每秒重建；離線守衛去重 |

## 需要你手動做（上架前）

1. **Release 簽章**：`keytool` 產一把 keystore（在 JDK / Android Studio 的 bin 底下），把 `android/key.properties.example` 複製成 `android/key.properties` 填入 4 個值。key.properties 與 .jks 都已在 .gitignore，別提交。
   ```
   keytool -genkey -v -keystore voicetype-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. **App icon**：放一張 1024×1024 PNG 到 `assets/icon/app_icon.png`，再跑 `dart run flutter_launcher_icons`。目前還是預設藍色 F。
3. **`flutter pub get`**：讓 flutter_launcher_icons 就位（pubspec.lock 已更新，跑一次確保本機同步）。
4. **實機 smoke test（我在此環境沒法跑）**：
   - 錄音 → 停止 → 轉錄 → 潤飾 → 存進歷史，確認整條 pipeline 正常、歷史有存到。
   - Android 背景錄音時通知是否正常、切背景不被系統殺。
   - `flutter build apk --release` 跑一次，測 R8 有沒有誤刪 plugin 類別（錄音、通知、Hive、桌面 widget 都點一遍）。R8 的問題只有在 release runtime 才看得出來。

## 加密遷移的安全說明

- 首次啟動會把舊的明文 `transcripts.hive` 轉成加密盒，並在同目錄留一份 `transcripts.plain.bak`（明文備份，安全網）。
- 確認歷史都在、轉錄正常後，你可以自行刪掉 `transcripts.plain.bak`（AppData/Local 的 hive 資料夾內）。留著 = 多一份明文；刪掉 = 完全加密。
- 遷移用「與資料同目錄的標記檔 `transcripts.encrypted`」判斷是否已做，避免標記與資料脫鉤導致誤刪。
- **金鑰存在 FlutterSecureStorage**（Windows Credential Manager）。金鑰若遺失，加密資料就讀不回來——這是 at-rest 加密的固有代價，`.plain.bak` 是最後防線。

## 已延後（有意為之，非遺漏）

- **API key 用 ChangeNotifierProxyProvider 集中同步**：`TranscriptionProvider.updateApiKey` 內部會 `notifyListeners()`，塞進 proxy 的 `update`（build 期間執行）會踩「build 中 notify」的雷。要做得先把 updateApiKey 改成 notify-safe。目前兩個畫面各自同步 key 的寫法照舊，功能正常。
- **`flutter_local_notifications` 17 → 18/19**：主版本有破壞性 API 變更，又跟這次重寫的通知系統重疊，兩個大改一起做風險過高，留作後續單獨處理。
- **R8 keep 規則**：目前是保守猜測（hive/record/notifications 套件名），實機 release 測到問題再補。

## 其他

- `test/widget_test.dart` 是空殼（`expect(true, isTrue)`），沒測到東西，可另外補真正的 smoke test。
