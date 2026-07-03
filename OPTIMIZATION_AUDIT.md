# VoiceType 優化稽核報告

> 六維度平行審查 + 對抗式驗證，31 個發現通過查證。
> 產出日期：2026-07-03

## 總評

程式功能完整、能跑，沒有會當機或洩漏 API key 的嚴重缺陷。問題集中在兩塊：發佈前的設定收尾，和單一巨型檔案的維護性。只有一個真正的硬阻擋——release 用 debug 金鑰簽章，Play Store 直接拒收；其餘多半是上架前的收尾工作，或日後長大才會咬人的技術債。以一個自用取代訂閱制的工具來說，體質算健康。

---

## 立刻該做（依 影響 × 信心 ÷ 工作量 排序）

### 1. Release 用 debug 金鑰簽章，Play Store 會拒收 — S
`flutter build appbundle --release` 產出的 AAB 是拿 Android debug 憑證簽的，上不了架，也沒有跨版本穩定的 upload key。
**做法**：建 release keystore，加 `key.properties`（進 .gitignore），gradle 載入並設定正式 `signingConfig`。
`android/app/build.gradle.kts:38`

### 2. 重複的錄音通知系統撞同一個 ID 4711 — M
Dart 的 `_plugin.show(4711)` 和原生 `startForeground(4711)` 搶同一格通知，互相覆蓋。停止錄音時 `_plugin.cancel(4711)` 可能把前景服務的通知一起取消；每秒更新 elapsed 又可能讓通知脫離前景服務綁定，最壞情況 Android 直接殺掉錄音中的行程。
**做法**：讓原生前景服務單獨擁有這個通知，elapsed 文字透過 MethodChannel 傳給原生更新，Dart 端不要再發 4711。
`lib/services/recording_notification_service.dart:19`（撞 `RecordingForegroundService.kt:90`）

### 3. 轉錄內容在硬碟上是明文 — M
使用者口述的全部內容（可能含私密、醫療、財務）用明文存在 Hive box，任何本機程序、備份工具或有檔案存取權的人打開 `.hive` 就能讀完整歷史。專案已經在用 `flutter_secure_storage` 存 API key，卻沒替 box 上鎖。
**做法**：用 `Hive.generateSecureKey()` 產 256-bit 金鑰、存進 FlutterSecureStorage，開 box 時帶 `HiveAesCipher(key)`，首次啟動把舊的明文 box 遷移過去。
`lib/services/hive_storage_init.dart:16`

### 4. 匯出的 txt/md/zip 寫進共用暫存目錄後不刪 — S
每次匯出都在暫存夾留一份明文轉錄內容，桌面版（Windows/macOS）不會被沙盒清掉，會無限累積且容易被還原；多筆彙整的 zip 尤其敏感。
**做法**：`Share.shareXFiles` 用 try/finally 分享結束後刪檔，或寫進啟動時清空的專屬子目錄，多筆 zip 避免可預測檔名。
`lib/services/export_service.dart:14`

### 5. home_screen.dart 是 2077 行的巨型檔 — L
一個 State class 扛了導覽、錄音流程、錯誤 UI、桌面標題列等 5 種以上職責，改任何一塊都得讀整個檔。標題列、待轉錄卡、錯誤面板這些其實可複用的 widget 因為是檔案私有，別的畫面用不到。
**做法**：拆成 `screens/home/`、`widgets/nav/`、`widgets/home/`，把錄音→停止→轉錄→整理→存檔這條 pipeline 抽進 `RecordingSessionController` 或 TranscriptionProvider，widget 只負責接 callback 和渲染。
`lib/screens/home_screen.dart:45` / `:393`

### 6. 錄音時整個 HomeStage 每秒重建約 11 次 — M
`_HomeStage.build()` 直接 `context.watch<RecordingProvider>()`，波形每 90ms 通知一次就把整棵子樹（含 TextField、SelectableText）重建，低階手機錄音時卡頓、耗電。
**做法**：把會跳動的部分（elapsed、波形）包進 scoped 的 `Consumer`／`Selector`，`_HomeStage` 層改用 `Selector` 只讀 `isRecording`／`hasContent` 這種 bool。
`lib/screens/home_screen.dart:1037`

---

## 值得做（medium）

### 架構
- API key 同步的樣板在 HomeScreen 和 HistoryDetailScreen 兩處逐字重複；根因是 TranscriptionProvider 自己讀不到 key。改法：main.dart 用 `ChangeNotifierProxyProvider` 讓它一次觀察 SettingsProvider。`lib/screens/home_screen.dart:85`
- `record_calendar_screen.dart`（697 行）是死碼，全專案沒有任何地方 import 或實例化。直接刪，或移出 lib/ 標成 WIP。`lib/screens/record_calendar_screen.dart:49`

### 建置／發佈
- release 沒開 R8／ProGuard（無 `isMinifyEnabled`、無 `proguard-rules.pro`），APK 沒瘦身也沒 keep 規則，之後才開 R8 可能誤刪反射用到的 plugin 類別。要加 keep 規則涵蓋 notifications／record／hive。`android/app/build.gradle.kts:34`
- `FOREGROUND_SERVICE_MICROPHONE` 有宣告，但服務自己的註解就寫「不擷取音訊、只是讓 OS 別殺行程」，這正是 Android 14+ 與 Play Console 會盯的樣態。要嘛把實際收音移進服務，要嘛送審前補上前景服務型別的宣告與說明。`RecordingForegroundService.kt:18`

---

## 可選／低優先

- 離線守衛＋SnackBar 在 home_screen 複製了四份、文案還不一致，抽成一個 `_guardOnline()`。`lib/screens/home_screen.dart:307`
- `_HomeStage` 傳 11 個參數、`_DocBody` 直接收整個 provider 物件，過度拆解又不給狀態存取；讓葉節點自己 `context.watch`。`lib/screens/home_screen.dart:1008`
- `_LiveWaveform` 每 tick 用 `map().toList()` 重建 34 個 Container，改成單一 `CustomPaint`。`lib/widgets/record_hud_pill.dart:183`
- `waveformSamples` getter 每次讀都 new 一個 unmodifiable List；快取或直接曝露 backing list。`lib/providers/recording_provider.dart:31`
- `waveformSamples` 用 `removeAt(0)` 是 O(n) 位移；改 ring buffer（n=80，影響很小）。`lib/providers/recording_provider.dart:113`
- `rawTranscript` 每次讀都 `map().join()` 重算；在 `_segments` 變動時才重建快取。`lib/providers/transcription_provider.dart:37`
- 歷史清單用 Column 而非 `ListView.builder`，搜尋每次 keystroke 全表重掃；資料量大才會卡，改懶載入＋debounce＋預算小寫索引。`lib/screens/history_screen.dart:240`
- WAV 切割與組裝在 UI isolate 同步跑，長錄音停止後會掉幾幀；用 `compute()` 丟背景 isolate。`lib/services/wav_split_service.dart:45`
- 原始 DioException 直接內插進可複製的錯誤字串，可能把伺服器回應細節帶進剪貼簿；統一走 `_debugLineForException` 那種只留型別＋HTTP status 的摘要。`lib/providers/transcription_provider.dart:342`
- OpenAI 回應欄位無驗證就 cast／取 index，格式不符會丟不透明錯誤；用前先檢查 `choices is List && isNotEmpty`、`content is String`。`lib/services/openai_service.dart:86`
- Windows secure storage 用 `useBackwardCompatibility:false` 且無失敗 fallback，Credential Manager 讀取失敗會讓 `_loadAll()` 拋出、卡在 loading；讀寫包 try/catch，失敗就當「未設 key」提示重輸。`lib/services/secure_storage_service.dart:14`
- App 名稱三種大小寫並存：Android label `voicetype`、iOS CFBundleName `voicetype`、CFBundleDisplayName `Voicetype`，全部對齊成 `VoiceType`。`android/app/src/main/AndroidManifest.xml:9`
- 直接依賴的下界 pin 偏鬆，`flutter_local_notifications` 還停在 17.x（18/19 已改了 Android 14 權限 API）；跑 `flutter pub outdated` 升版並重測通知。`pubspec.yaml:52`
- 沒有自訂 App icon，還是預設 Flutter 藍色 F；上架前用 `flutter_launcher_icons` 產各密度品牌圖示。`android/app/src/main/AndroidManifest.xml:11`
- 字級設定顯示 4 個 chip，但存的原始 scale 可能是第 5 個值（0.85／1.35），沒有 chip 對得上；載入時 snap 到最近的 chip 並存回。`lib/providers/settings_provider.dart:50`
- 自訂麥克風／停止按鈕與 tab 低於 48×48 觸控最小值，bare GestureDetector 對 TalkBack／VoiceOver 又無 label；包 `Semantics(button:true)` 並補足點擊區。`lib/widgets/record_hud_pill.dart:144`
- heatmap 顏色與 titlebar／stop-dot 的 ink 寫死、繞過 AppTokens；改走 `context.tokens`。`lib/screens/record_calendar_screen.dart:15`
- 歷史載入失敗但清單非空時，錯誤訊息算好了卻沒任何地方顯示，使用者看到舊資料卻不知道 reload 失敗；`loadError != null && records.isNotEmpty` 時給個可關閉的 banner。`lib/screens/history_screen.dart:165`
- 「費用粗估（新台幣）」寫死 TWD 與匯率 32，換模型或改價會悄悄失準；把幣別／匯率參數化並標清楚是 app 端估算。`lib/screens/settings_screen.dart:157`
- 所有 UI 字串都是寫死的繁體中文、沒有 i18n 層。若確定單一語系就寫進文件說明；否則抽到 intl／gen-l10n 並補 `localizationsDelegates`。`lib/screens/home_screen.dart:330`

---

## 建議動手順序

1. **先清上架硬阻擋**：release keystore 簽章（#1）。這是唯一擋住出貨的項目，S 工作量，先做。
2. **修通知 ID 撞號（#2）**：關係到錄音會不會被系統殺掉，功能正確性優先於美化，同時把前景服務型別宣告一起處理。
3. **補資料保護**：Hive 加密（#3）＋匯出暫存檔清理（#4），兩筆都是敏感語音內容的 at-rest 曝險，一起收。
4. **拆 home_screen（#5）＋修錄音重建效能（#6）**：抽 orchestration 進 controller 的同時，順手用 Selector 收掉每秒 11 次重建，一趟改兩件事。L 工作量，放在阻擋清完後做。
5. **上架收尾＋清死碼**：R8、App icon、label 大小寫、刪 `record_calendar_screen`。各自獨立、S 為主，可零碎時間清掉。
