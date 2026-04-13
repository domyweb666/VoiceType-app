import 'dart:io';

import 'package:dio/dio.dart';

/// 弱網、逾時、伺服器暫時錯誤等可重試；金鑰錯誤、內容錯誤不重試。
bool isRetryableOpenAIRequestError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == null) return true;
        if (code == 401 || code == 403) return false;
        if (code == 400 || code == 413 || code == 422) return false;
        return code == 408 || code == 429 || code >= 500;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
      case DioExceptionType.unknown:
        return error.error is SocketException;
    }
  }
  return false;
}
