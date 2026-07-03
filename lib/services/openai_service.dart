import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../config/constants.dart';
import '../models/chat_organize_result.dart';

class OpenAIService {
  final Dio _dio;

  OpenAIService({required String apiKey})
      : _dio = Dio(BaseOptions(
          baseUrl: AppConstants.openaiBaseUrl,
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  void updateApiKey(String apiKey) {
    _dio.options.headers['Authorization'] = 'Bearer $apiKey';
  }

  static String _filenameForUpload(File audioFile) {
    final name = p.basename(audioFile.path);
    return name.isNotEmpty ? name : 'audio.wav';
  }

  static DioMediaType _audioContentTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.wav')) return DioMediaType('audio', 'wav');
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4') || lower.endsWith('.mpeg')) {
      return DioMediaType('audio', 'mp4');
    }
    if (lower.endsWith('.mp3') || lower.endsWith('.mpga')) {
      return DioMediaType('audio', 'mpeg');
    }
    if (lower.endsWith('.webm')) return DioMediaType('audio', 'webm');
    return DioMediaType('audio', 'wav');
  }

  Future<String> transcribeAudio(File audioFile, {String? prompt}) async {
    final filename = _filenameForUpload(audioFile);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioFile.path,
        filename: filename,
        contentType: _audioContentTypeForFilename(filename),
      ),
      'model': AppConstants.whisperModel,
      'language': AppConstants.whisperLanguage,
      'response_format': 'text',
      if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
    });

    final response = await _dio.post(
      '/audio/transcriptions',
      data: formData,
    );

    final data = response.data;
    if (data is! String) {
      throw const FormatException('轉錄回應格式異常（預期為文字內容）');
    }
    return data.trim();
  }

  Future<ChatOrganizeResult> organizeText(
    String rawTranscript, {
    required String systemPrompt,
  }) async {
    final response = await _dio.post(
      '/chat/completions',
      data: {
        'model': AppConstants.gptModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': rawTranscript},
        ],
        'temperature': AppConstants.gptTemperature,
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 120),
      ),
    );

    final rawData = response.data;
    if (rawData is! Map) {
      throw const FormatException('潤飾回應格式異常（預期為物件）');
    }
    final data = Map<String, dynamic>.from(rawData);

    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('潤飾回應缺少 choices 內容');
    }
    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      throw const FormatException('潤飾回應 choices 格式異常');
    }
    final message = firstChoice['message'];
    if (message is! Map) {
      throw const FormatException('潤飾回應缺少 message 內容');
    }
    final content = message['content'];
    if (content is! String) {
      throw const FormatException('潤飾回應缺少文字內容');
    }
    final text = content;

    int? promptTokens;
    int? completionTokens;
    final usage = data['usage'];
    if (usage is Map<String, dynamic>) {
      final pt = usage['prompt_tokens'];
      final ct = usage['completion_tokens'];
      if (pt is int) promptTokens = pt;
      if (ct is int) completionTokens = ct;
    }
    return ChatOrganizeResult(
      text: text,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }
}
