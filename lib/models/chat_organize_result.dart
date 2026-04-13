/// 潤飾（chat completions）回傳內容與用量（若 API 有回傳）。
class ChatOrganizeResult {
  final String text;
  final int? promptTokens;
  final int? completionTokens;

  const ChatOrganizeResult({
    required this.text,
    this.promptTokens,
    this.completionTokens,
  });
}
