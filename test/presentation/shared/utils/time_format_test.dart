import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

void main() {
  test('formatTime describes elapsed seconds in Korean units', () {
    expect(formatTime(0), '0초');
    expect(formatTime(-5), '0초');
    expect(formatTime(45), '45초');
    expect(formatTime(120), '2분');
    expect(formatTime(125), '2분 5초');
    expect(formatTime(3600), '1시간');
    expect(formatTime(3660), '1시간 1분');
  });

  test('formatTimeTimer uses timer display with hours when needed', () {
    expect(formatTimeTimer(65), '01 : 05');
    expect(formatTimeTimer(3665), '01 : 01 : 05');
  });

  test('formatEalyLateTime reports absolute early or late minutes', () {
    expect(formatEalyLateTime(-90), '1분');
    expect(formatEalyLateTime(3900), '1시간 5분');
  });

  test('formatElapsedTime keeps seconds two-digit padded', () {
    expect(formatElapsedTime(65), '1분 05초');
  });
}
