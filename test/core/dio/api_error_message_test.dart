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

  test('maps schedule lifecycle conflict codes to client messages', () {
    expect(
      ApiErrorMessage.fromResponseData({
        'status': 'error',
        'code': 'SCHEDULE_ALREADY_STARTED',
        'message': 'Started schedules cannot be edited.',
        'data': null,
      }),
      'This schedule has already started and can no longer be edited.',
    );
    expect(
      ApiErrorMessage.fromResponseData({
        'status': 'error',
        'code': 'SCHEDULE_ALREADY_FINISHED',
        'message': 'Finished schedules cannot be edited.',
        'data': null,
      }),
      'This schedule has already finished and can no longer be edited.',
    );
    expect(
      ApiErrorMessage.fromResponseData({
        'status': 'error',
        'code': 'SCHEDULE_NOT_STARTED',
        'message': 'Schedules must be started before they can be finished.',
        'data': null,
      }),
      'Start preparation before finishing this schedule.',
    );
  });
}
