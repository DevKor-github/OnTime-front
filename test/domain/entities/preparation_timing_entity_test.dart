import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

void main() {
  group('Preparation timing entities', () {
    final preparation = PreparationWithTimeEntity(
      preparationStepList: const [
        PreparationStepWithTimeEntity(
          id: 's1',
          preparationName: 'wash',
          preparationTime: Duration(minutes: 10),
          nextPreparationId: 's2',
        ),
        PreparationStepWithTimeEntity(
          id: 's2',
          preparationName: 'dress',
          preparationTime: Duration(minutes: 10),
          nextPreparationId: null,
        ),
      ],
    );

    final schedule = ScheduleWithPreparationEntity(
      id: 'schedule-1',
      place: PlaceEntity(id: 'p1', placeName: 'Office'),
      scheduleName: 'Meeting',
      scheduleTime: DateTime(2026, 3, 20, 10, 0),
      moveTime: const Duration(minutes: 20),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 10),
      scheduleNote: '',
      preparation: preparation,
    );

    test('calculates time remaining and late status with explicit now', () {
      final now = DateTime(2026, 3, 20, 9, 20);
      expect(
        schedule.timeRemainingBeforeLeavingAt(now),
        const Duration(minutes: 10),
      );
      expect(schedule.isLateAt(now), isFalse);

      final lateNow = DateTime(2026, 3, 20, 9, 31);
      expect(schedule.timeRemainingBeforeLeavingAt(lateNow).isNegative, isTrue);
      expect(schedule.isLateAt(lateNow), isTrue);
    });

    test('fast-forwards preparation steps for late entry', () {
      final progressed = preparation.timeElapsed(const Duration(minutes: 15));
      expect(progressed.preparationStepList[0].isDone, isTrue);
      expect(progressed.preparationStepList[1].isDone, isFalse);
      expect(progressed.currentStep?.id, 's2');
      expect(progressed.preparationStepList[1].elapsedTime,
          const Duration(minutes: 5));
    });

    test('marks all steps done for very late entry inside schedule window', () {
      final progressed = preparation.timeElapsed(const Duration(minutes: 40));
      expect(progressed.isAllStepsDone, isTrue);
      expect(progressed.currentStepRemainingTime, Duration.zero);
      expect(progressed.progress, 1.0);
    });

    test('cache fingerprint changes when preparation step name changes', () {
      final baseline = ScheduleWithPreparationEntity(
        id: 'schedule-cache',
        place: PlaceEntity(id: 'p1', placeName: 'Office'),
        scheduleName: 'Meeting',
        scheduleTime: DateTime(2026, 3, 20, 10, 0),
        moveTime: const Duration(minutes: 20),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 10),
        scheduleNote: '',
        preparation: const PreparationWithTimeEntity(
          preparationStepList: [
            PreparationStepWithTimeEntity(
              id: 's1',
              preparationName: 'Wash',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        ),
      );
      final renamed = ScheduleWithPreparationEntity(
        id: 'schedule-cache',
        place: PlaceEntity(id: 'p1', placeName: 'Office'),
        scheduleName: 'Meeting',
        scheduleTime: DateTime(2026, 3, 20, 10, 0),
        moveTime: const Duration(minutes: 20),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 10),
        scheduleNote: '',
        preparation: const PreparationWithTimeEntity(
          preparationStepList: [
            PreparationStepWithTimeEntity(
              id: 's1',
              preparationName: 'Makeup',
              preparationTime: Duration(minutes: 10),
              nextPreparationId: null,
            ),
          ],
        ),
      );

      expect(
          baseline.cacheFingerprint, isNot(equals(renamed.cacheFingerprint)));
    });
  });

  group('ScheduleState timing helper', () {
    test('durationUntilPreparationStartAt uses injected now deterministically',
        () {
      final preparation = PreparationWithTimeEntity(
        preparationStepList: const [
          PreparationStepWithTimeEntity(
            id: 's1',
            preparationName: 'prep',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );
      final schedule = ScheduleWithPreparationEntity(
        id: 'schedule-2',
        place: PlaceEntity(id: 'p1', placeName: 'Office'),
        scheduleName: 'Meeting',
        scheduleTime: DateTime(2026, 3, 20, 10, 0),
        moveTime: const Duration(minutes: 20),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 10),
        scheduleNote: '',
        preparation: preparation,
      );
      final state = ScheduleState.upcoming(schedule);

      final now = DateTime(2026, 3, 20, 9, 15);
      expect(
        state.durationUntilPreparationStartAt(now),
        const Duration(minutes: 5),
      );
    });
  });
}
