import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/home/utils/today_tile_navigation.dart';

void main() {
  group('Today tile navigation resolver', () {
    test(
        'returns early-start scheduleStart target in upcoming when schedule exists',
        () {
      final target = resolveTodayTileNavigationTarget(
        scheduleStatus: ScheduleStatus.upcoming,
        hasSchedule: true,
      );

      expect(target, isNotNull);
      expect(target!.path, '/scheduleStart');
      expect(target.extra, {'promptVariant': 'earlyStart'});
    });

    test('returns alarmScreen target in ongoing when schedule exists', () {
      final target = resolveTodayTileNavigationTarget(
        scheduleStatus: ScheduleStatus.ongoing,
        hasSchedule: true,
      );

      expect(target, isNotNull);
      expect(target!.path, '/alarmScreen');
      expect(target.extra, isNull);
    });

    test('returns alarmScreen target in started when schedule exists', () {
      final target = resolveTodayTileNavigationTarget(
        scheduleStatus: ScheduleStatus.started,
        hasSchedule: true,
      );

      expect(target, isNotNull);
      expect(target!.path, '/alarmScreen');
      expect(target.extra, isNull);
    });

    test('returns null when no schedule exists', () {
      final target = resolveTodayTileNavigationTarget(
        scheduleStatus: ScheduleStatus.upcoming,
        hasSchedule: false,
      );

      expect(target, isNull);
    });

    test('returns null in initial and notExists', () {
      final initialTarget = resolveTodayTileNavigationTarget(
        scheduleStatus: ScheduleStatus.initial,
        hasSchedule: true,
      );
      final notExistsTarget = resolveTodayTileNavigationTarget(
        scheduleStatus: ScheduleStatus.notExists,
        hasSchedule: true,
      );

      expect(initialTarget, isNull);
      expect(notExistsTarget, isNull);
    });
  });
}
