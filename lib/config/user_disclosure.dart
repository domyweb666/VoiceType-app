/// 隱私與費用說明（設定頁與首次提示共用）。
class UserDisclosure {
  UserDisclosure._();

  static const String privacyAndCostTitle = '隱私與費用';

  static const String privacyAndCostBody = '''
• 音訊與轉錄：結束錄音後，App 會自動將整段錄音（必要時切成數段）上傳至 OpenAI 轉成口語稿，接著自動將口語稿送至聊天／語言模型潤飾成文字稿，並存進本機歷史。傳輸受各該服務條款與隱私政策規範。

• 儲存位置：API 金鑰與偏好設定儲存在本裝置（SharedPreferences）；逐字稿與歷史紀錄在 Hive。本 App 營運方無法存取你的錄音或文字。

• 費用：使用 OpenAI API 會依官方計價計費。設定頁有以新台幣呈現的粗估；實際金額以帳單為準。

• 網路：弱網或伺服器忙碌時，App 會自動重試部分失敗請求；若仍失敗，請檢查連線或稍後再試。''';
}
