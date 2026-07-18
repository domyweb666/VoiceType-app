/// 語音轉錄引擎（潤飾一律走 OpenAI GPT）。
enum AsrEngine {
  /// OpenAI Whisper（gpt-4o-mini-transcribe），與潤飾共用同一把金鑰。
  openai,

  /// BytePlus Seed Speech ASR（字節跳動海外站），中文辨識較準，需另一把金鑰。
  byteplus,
}

class AppConstants {
  static const String whisperModel = 'gpt-4o-mini-transcribe';
  static const String gptModel = 'gpt-4o-mini';
  static const String openaiBaseUrl = 'https://api.openai.com/v1';

  /// BytePlus Seed ASR（Audio File 2.0 / bigmodel）非同步轉錄端點。
  static const String bytePlusAsrBaseUrl =
      'https://voice.ap-southeast-1.bytepluses.com/api/v3/auc/bigmodel';
  static const String bytePlusResourceId = 'volc.seedasr.auc';
  static const String bytePlusModelName = 'bigmodel';

  /// Seed ASR 的語言碼；輸出可能為簡體，由潤飾階段統一轉臺灣繁體。
  static const String bytePlusLanguage = 'zh-CN';
  static const Duration bytePlusPollInterval = Duration(seconds: 2);
  static const Duration bytePlusMaxWait = Duration(minutes: 10);

  /// 金鑰申請頁（設定頁「如何取得金鑰」連結）。
  static const String openaiKeyHelpUrl = 'https://platform.openai.com/api-keys';
  static const String bytePlusKeyHelpUrl = 'https://console.byteplus.com/';

  /// 作者聯絡／工具介紹頁（設定頁「聯絡多米」連結）。
  static const String authorContactUrl = 'https://domyweb.org/tools/voicetype/';

  /// 贊助頁（設定頁「請多米喝杯咖啡」連結）。
  static const String authorCoffeeUrl = 'https://portaly.cc/domyweb/support';
  /// 錄音結束後轉錄時，每段 WAV 最長秒數（避免超過 API 單檔約 25MB 上限）。
  /// （OpenAI 語音轉錄端點對單一檔案大小有上限，官方文件目前為約 25MB。）
  static const int postRecordTranscribeSliceSeconds = 600;

  /// 轉錄 API 單檔位元組上限（與官方約 25MB 對齊，供本機預檢）。
  static const int maxOpenAITranscribeFileBytes = 25 * 1024 * 1024;

  static const String oversizedTranscribeFileUserHint =
      '單檔超過 OpenAI 轉錄上限（約 25MB）。請縮短音檔、改匯出為較短的 WAV，'
      '或使用 App 內錄音（長錄音會自動切段）。M4A 等單檔無法切段時尤須注意檔案大小。';

  /// 應用程式文件目錄下，待轉錄 WAV 佇列子路徑（相對於 documents）。
  static const String pendingTranscriptionRelativeDir =
      'voice_type/pending_transcription';

  static const int sampleRate = 16000;
  static const int numChannels = 1;
  static const int bitsPerSample = 16;
  static const String whisperLanguage = 'zh';

  /// 轉錄 API 的 `prompt` 前綴（與前段逐字銜接並列於字數上限內）。
  static const String transcriptionTraditionalHint =
      '請以臺灣繁體中文（正體字）逐字轉錄，維持口述用語，勿改寫、勿換成簡體字。';

  static const int maxPromptChars = 200;
  static const double gptTemperature = 0.3;

  /// 轉錄失敗時的重試次數（含首次請求，共 N 次嘗試）。
  static const int transcriptionMaxAttempts = 4;

  /// 轉錄重試：首次失敗後等待時間，之後指數退避（×2）。
  static const Duration transcriptionRetryBaseDelay = Duration(seconds: 2);

  /// 整理（口語稿／正式）API 失敗時的最大嘗試次數。
  static const int organizeMaxAttempts = 3;

  static const Duration organizeRetryBaseDelay = Duration(seconds: 2);

  /// 文字稿潤飾用 system 提示詞：最小化干預、不加標題。
  static const String oralDraftSystemPrompt = '''
角色設定：
你是一位擅長「最小化干預」的文字編輯。你的任務是將口語錄音轉出的稿件，在不改變原作者說話風格與語氣的前提下，微調成適合閱讀的文字。

潤飾規則：

只刪除贅字： 去除無意義的發聲詞（如：呃、那個、然後、對、就是說、其實、那...）。

修正斷句： 將過長的句子拆解，或將破碎的語法微調成通順的句子，但不可影響語意。

嚴禁重寫： 禁止將口語改為書面的「公文腔」或「教科書體」。如果原句使用了特定的俗語、俚語或幽默感，請原封不動保留。

保留語序： 除非邏輯完全混亂，否則請保留原作者說話的思維跳躍與順序。

標點符號： 根據語氣加上正確的標點，提升可讀性。

禁止標題： 不要加入小標題、章節標題或任何形式的標題行（含 Markdown 的 # 標題、獨立一行的主題名稱等）。全文為連續正文。

字形與用詞： 全文以臺灣繁體中文（正體字）呈現；若有簡體字，僅改為對應繁體字形，不以同義詞替換原詞。英文與專有名詞維持原樣。

輸出格式：
請直接輸出潤飾後的文字，不需要解釋你做了哪些修改。''';
}

