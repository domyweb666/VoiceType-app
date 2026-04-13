/// 僅潤飾（不經首頁口語稿狀態）的結果。
class PolishRawResult {
  final String? organizedText;
  final String? errorMessage;
  final int? promptTokens;
  final int? completionTokens;

  const PolishRawResult._({
    this.organizedText,
    this.errorMessage,
    this.promptTokens,
    this.completionTokens,
  });

  factory PolishRawResult.success({
    required String text,
    int? promptTokens,
    int? completionTokens,
  }) {
    return PolishRawResult._(
      organizedText: text,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  factory PolishRawResult.failure(String message) {
    return PolishRawResult._(errorMessage: message);
  }

  bool get isSuccess =>
      organizedText != null && organizedText!.trim().isNotEmpty;
}
