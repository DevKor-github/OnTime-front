import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/dio/api_error_message.dart';

void main() {
  test('extracts top-level backend validation message', () {
    final message = ApiErrorMessage.fromResponseData({
      'status': 'error',
      'code': 1002,
      'message': '유효하지 않은 입력값입니다.',
      'data': {
        'errors': [
          {'field': 'email', 'message': '이메일 형식이 올바르지 않습니다.'},
        ],
      },
    });

    expect(message, '유효하지 않은 입력값입니다.');
  });

  test(
    'falls back to first field message when top-level message is absent',
    () {
      final message = ApiErrorMessage.fromResponseData({
        'data': {
          'errors': [
            {'field': 'email', 'message': '이메일 형식이 올바르지 않습니다.'},
          ],
        },
      });

      expect(message, '이메일 형식이 올바르지 않습니다.');
    },
  );
}
