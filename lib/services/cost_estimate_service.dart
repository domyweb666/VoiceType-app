import '../config/constants.dart';

/// 依目前 App 流程（轉錄 + 一次潤飾）粗估費用；對外說明以**新台幣**呈現。
/// 內部仍以美元單價換算；實際帳單以 OpenAI 為準，請對照官網調整常數。
class SessionCostEstimateService {
  SessionCostEstimateService._();

  /// 語音轉錄：美元／分鐘（`gpt-4o-mini-transcribe` 常見區間，請以官網為準）。
  static const double transcribeUsdPerAudioMinute = 0.003;

  /// 潤飾：`gpt-4o-mini` 每百萬 token 美元（標準方案，請以官網為準）。
  static const double gpt4oMiniInputUsdPer1M = 0.15;
  static const double gpt4oMiniOutputUsdPer1M = 0.60;

  /// 粗估口語稿字數：中文口述約略字數／分鐘（僅供換算 token 量級）。
  static const double assumedCharsPerSpokenMinute = 320;

  /// 新台幣／美元匯率假設（可自行修改）。
  static const double twdPerUsd = 32.0;

  /// 系統提示詞約略 token 量（潤飾請求 input 的一部分）。
  static const double assumedSystemPromptTokens = 650;

  static double _organizeUsdForAudioMinutes(double audioMinutes) {
    final chars = audioMinutes * assumedCharsPerSpokenMinute;
    // 中文粗估：約 1 token ≈ 1.3～1.5 字，此處取 1.4
    final userTokens = chars / 1.4;
    final inputTokens = assumedSystemPromptTokens + userTokens;
    final outputTokens = userTokens * 0.95;
    final inputUsd = (inputTokens / 1e6) * gpt4oMiniInputUsdPer1M;
    final outputUsd = (outputTokens / 1e6) * gpt4oMiniOutputUsdPer1M;
    return inputUsd + outputUsd;
  }

  /// 單次「錄音 → 口語稿 → 文字稿」流程粗估（美元）。
  static double estimateSessionUsd({required int recordingMinutes}) {
    if (recordingMinutes <= 0) return 0;
    final m = recordingMinutes.toDouble();
    final transcribe = m * transcribeUsdPerAudioMinute;
    final organize = _organizeUsdForAudioMinutes(m);
    return transcribe + organize;
  }

  static double estimateSessionTwd({required int recordingMinutes}) {
    return estimateSessionUsd(recordingMinutes: recordingMinutes) * twdPerUsd;
  }

  static double _transcribeUsdForAudioSeconds(int audioSeconds) {
    if (audioSeconds <= 0) return 0;
    final minutes = audioSeconds / 60.0;
    return minutes * transcribeUsdPerAudioMinute;
  }

  static double _organizeUsdFromTokens({
    required int promptTokens,
    required int completionTokens,
  }) {
    final inputUsd = (promptTokens / 1e6) * gpt4oMiniInputUsdPer1M;
    final outputUsd = (completionTokens / 1e6) * gpt4oMiniOutputUsdPer1M;
    return inputUsd + outputUsd;
  }

  /// 本次「轉錄 + 潤飾」粗估新台幣區間（寬鬆乘數，不承諾與帳單一致）。
  static String buildRoundTripTwdRangeHint({
    required int audioSeconds,
    int? organizePromptTokens,
    int? organizeCompletionTokens,
    required int rawTranscriptCharCount,
  }) {
    final transcribeUsd = _transcribeUsdForAudioSeconds(audioSeconds);

    double organizeUsd;
    if (organizePromptTokens != null && organizeCompletionTokens != null) {
      organizeUsd = _organizeUsdFromTokens(
        promptTokens: organizePromptTokens,
        completionTokens: organizeCompletionTokens,
      );
    } else {
      final approxMinutesFromText =
          (rawTranscriptCharCount / assumedCharsPerSpokenMinute)
              .clamp(1 / 60, 1e6);
      organizeUsd = _organizeUsdForAudioMinutes(approxMinutesFromText);
    }

    final usd = transcribeUsd + organizeUsd;
    final twd = usd * twdPerUsd;
    final low = (twd * 0.75).clamp(0, double.infinity);
    final high = (twd * 1.35).clamp(0, double.infinity);
    return '本次操作粗估約新台幣 ${low.toStringAsFixed(2)}～${high.toStringAsFixed(2)} 元'
        '（依錄音長度與 API 回傳 token 粗算，實際以 OpenAI 帳單為準）。';
  }

  /// 僅潤飾（無轉錄）一輪的新台幣區間粗估。
  static String buildPolishOnlyTwdRangeHint({
    int? organizePromptTokens,
    int? organizeCompletionTokens,
    required int rawTranscriptCharCount,
  }) {
    double organizeUsd;
    if (organizePromptTokens != null && organizeCompletionTokens != null) {
      organizeUsd = _organizeUsdFromTokens(
        promptTokens: organizePromptTokens,
        completionTokens: organizeCompletionTokens,
      );
    } else {
      final approxMinutesFromText =
          (rawTranscriptCharCount / assumedCharsPerSpokenMinute)
              .clamp(1 / 60, 1e6);
      organizeUsd = _organizeUsdForAudioMinutes(approxMinutesFromText);
    }
    final twd = organizeUsd * twdPerUsd;
    final low = (twd * 0.75).clamp(0, double.infinity);
    final high = (twd * 1.35).clamp(0, double.infinity);
    return '本次僅潤飾粗估約新台幣 ${low.toStringAsFixed(2)}～${high.toStringAsFixed(2)} 元'
        '（不含轉錄；實際以 OpenAI 帳單為準）。';
  }

  /// 產生設定頁用多行說明（**金額一律以新台幣表示**）。
  static String buildSettingsEstimateText() {
    final b10 = estimateSessionTwd(recordingMinutes: 10);
    final b20 = estimateSessionTwd(recordingMinutes: 20);
    final b30 = estimateSessionTwd(recordingMinutes: 30);
    return '以下為「轉錄 + 自動潤飾一次」合計之粗估，金額皆為新台幣：\n\n'
        '內部依 OpenAI 美金計價換算（匯率假設 1 美元 ≈ ${twdPerUsd.toStringAsFixed(0)} 新台幣，可自行改程式常數）。\n'
        '模型：轉錄 ${AppConstants.whisperModel}；潤飾 ${AppConstants.gptModel}。\n\n'
        '• 錄 10 分鐘：約新台幣 ${b10.toStringAsFixed(2)} 元\n'
        '• 錄 20 分鐘：約新台幣 ${b20.toStringAsFixed(2)} 元\n'
        '• 錄 30 分鐘：約新台幣 ${b30.toStringAsFixed(2)} 元\n\n'
        '實際費用受語速、靜音、重試、匯率與 OpenAI 調價影響；請以帳單為準。\n\n'
        '首頁每完成「轉錄 + 潤飾並存檔」一輪後，會另顯示與該次較相關的粗估區間（仍非精確帳單）。';
  }
}
