# VoiceType 的 ProGuard / R8 保留規則
#
# release build 開啟了 isMinifyEnabled 與 isShrinkResources，R8 會移除
# 看似沒被引用到的類別。以下規則保守地保留幾個「靠反射或原生 JNI 取用、
# R8 無法靜態追蹤到」的類別，避免 release 版執行期崩潰。
# 若之後移除相關套件，記得同步清掉對應規則。

# --- flutter_local_notifications ---
# 需要保留通知排程與接收相關類別（部分靠反射與 AndroidManifest 註冊）。
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# --- record 錄音套件 ---
-keep class com.llfbandit.record.** { *; }

# --- Hive / hive_flutter ---
# Hive 以反射存取 TypeAdapter，保留產生的 adapter 與相關類別。
-keep class hive.** { *; }
-keep class * extends hive.HiveObject { *; }
-keep class **.*Adapter { *; }

# --- 本 App 自己在 AndroidManifest 內宣告的類別 ---
# 這些類別由 manifest 以字串名稱參照（Service / Activity / AppWidgetProvider），
# R8 可能誤判未使用而移除，明確保留。
-keep class com.voicetype.voicetype.RecordingForegroundService { *; }
-keep class com.voicetype.voicetype.RecordWidgetProvider { *; }
-keep class com.voicetype.voicetype.MainActivity { *; }
