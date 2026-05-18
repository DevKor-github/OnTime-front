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

    final codeMessage = _messageFromCode(data['code']);
    if (codeMessage != null) {
      return codeMessage;
    }

    final error = data['error'];
    if (error is Map<String, dynamic>) {
      final nestedCodeMessage = _messageFromCode(error['code']);
      if (nestedCodeMessage != null) {
        return nestedCodeMessage;
      }
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

  static String? _messageFromCode(Object? code) {
    if (code is! String) {
      return null;
    }
    return switch (code) {
      'PREPARATION_TEMPLATE_NOT_FOUND' => 'Preparation template not found.',
      'PREPARATION_TEMPLATE_NAME_DUPLICATE' =>
        'A preparation template with this name already exists.',
      'PREPARATION_TEMPLATE_LIMIT_EXCEEDED' =>
        'You can create up to 20 active preparation templates.',
      'PREPARATION_TEMPLATE_DELETED' =>
        'This preparation template has been deleted.',
      'PREPARATION_STEP_ID_CONFLICT' =>
        'A preparation step ID is already used by another preparation.',
      'INVALID_INPUT' => 'Invalid input.',
      _ => null,
    };
  }
}
