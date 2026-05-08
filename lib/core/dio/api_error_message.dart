import 'package:dio/dio.dart';

class ApiErrorMessage {
  const ApiErrorMessage._();

  static String? fromException(Object error) {
    if (error is DioException) {
      return fromResponseData(error.response?.data);
    }
    return null;
  }

  static String? fromResponseData(Object? data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    final errors = data['data'];
    if (errors is Map<String, dynamic>) {
      final errorList = errors['errors'];
      if (errorList is List && errorList.isNotEmpty) {
        final firstError = errorList.first;
        if (firstError is Map<String, dynamic>) {
          final fieldMessage = firstError['message'];
          if (fieldMessage is String && fieldMessage.trim().isNotEmpty) {
            return fieldMessage.trim();
          }
        }
      }
    }

    return null;
  }
}
