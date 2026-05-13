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

    final code = data['code'];
    if (code == 'SCHEDULE_ALREADY_STARTED') {
      return 'This schedule has already started and can no longer be edited.';
    }
    if (code == 'SCHEDULE_ALREADY_FINISHED') {
      return 'This schedule has already finished and can no longer be edited.';
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
