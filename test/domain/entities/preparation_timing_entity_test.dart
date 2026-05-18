import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

void main() {
  group('Preparation timing entities', () {
    test('orders linked preparation steps before timing conversion', () {
      final unordered = PreparationEntity(
        preparationStepList: const [
          PreparationStepEntity(
            id: 's3',
            preparationName: 'pack',
            preparationTime: Duration(minutes: 5),
            nextPreparationId: null,
          ),
          PreparationStepEntity(
            id: 's1',
            preparationName: 'wash',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: 's2',
          ),
          PreparationStepEntity(
            id: 's2',
            preparationName: 'dress',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: 's3',
          ),
        ],
      );

      final preparation = PreparationWithTimeEntity.fromPreparation(unordered);

      expect(preparation.preparationStepList.map((step) => step.id).toList(), [
        's1',
        's2',
        's3',
      ]);
      expect(preparation.currentStep?.id, 's1');
    });

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

    test('calculates left time before leave with explicit now', () {
      final now = DateTime(2026, 3, 20, 9, 20);
      expect(
        schedule.timeRemainingBeforeLeavingAt(now),
        const Duration(minutes: 10),
      );
    });

    test('reports late status after leave time has passed', () {
      final now = DateTime(2026, 3, 20, 9, 20);
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
      expect(
        progressed.preparationStepList[1].elapsedTime,
        const Duration(minutes: 5),
      );
    });

    test('single preparation step tracks elapsed time and diagnostics', () {
      const step = PreparationStepWithTimeEntity(
        id: 's1',
        preparationName: 'wash',
        preparationTime: Duration(minutes: 10),
        nextPreparationId: 's2',
      );

      final partial = step.timeElapsed(const Duration(minutes: 4));
      final completed = partial.timeElapsed(const Duration(minutes: 6));
      final renamed = step.copyWith(preparationName: 'shower');

      expect(partial.elapsedTime, const Duration(minutes: 4));
      expect(partial.isDone, isFalse);
      expect(completed.elapsedTime, const Duration(minutes: 10));
      expect(completed.isDone, isTrue);
      expect(renamed.preparationName, 'shower');
      expect(step.toString(), contains('PreparationStepWithTimeEntity'));
      expect(step.props, [
        's1',
        'wash',
        const Duration(minutes: 10),
        's2',
        Duration.zero,
        false,
      ]);
    });

    test('marks all steps done for very late entry inside schedule window', () {
      final progressed = preparation.timeElapsed(const Duration(minutes: 40));
      expect(progressed.isAllStepsDone, isTrue);
      expect(progressed.currentStepRemainingTime, Duration.zero);
      expect(progressed.progress, 1.0);
    });

    test('reports display helpers for current and completed steps', () {
      final progressed = preparation.timeElapsed(const Duration(minutes: 12));

      expect(progressed.elapsedTime, const Duration(minutes: 12));
      expect(progressed.currentStepIndex, 1);
      expect(progressed.resolvedCurrentStepIndex, 1);
      expect(progressed.currentStepRemainingTime, const Duration(minutes: 8));
      expect(progressed.currentStepName, 'dress');
      expect(progressed.stepElapsedTimesInSeconds, [600, 120]);
      expect(progressed.preparationStepStates, [
        PreparationStateEnum.done,
        PreparationStateEnum.now,
      ]);
      expect(progressed.progress, 0.6);
    });

    test('skipCurrentStep marks only the active step done', () {
      final skipped = preparation.skipCurrentStep();

      expect(skipped.preparationStepList[0].isDone, isTrue);
      expect(skipped.preparationStepList[1].isDone, isFalse);
      expect(skipped.currentStep?.id, 's2');
      expect(skipped.preparationStepStates, [
        PreparationStateEnum.done,
        PreparationStateEnum.now,
      ]);
    });

    test('completed and empty preparations expose safe display fallbacks', () {
      final completed = preparation.timeElapsed(const Duration(minutes: 20));
      const empty = PreparationWithTimeEntity(preparationStepList: []);
      const zeroDuration = PreparationWithTimeEntity(
        preparationStepList: [
          PreparationStepWithTimeEntity(
            id: 'zero',
            preparationName: 'No-op',
            preparationTime: Duration.zero,
            nextPreparationId: null,
          ),
        ],
      );

      expect(completed.currentStepIndex, -1);
      expect(completed.resolvedCurrentStepIndex, 1);
      expect(completed.currentStepName, 'dress');
      expect(completed.preparationStepStates, [
        PreparationStateEnum.done,
        PreparationStateEnum.done,
      ]);
      expect(completed.skipCurrentStep(), same(completed));
      expect(
        completed.timeElapsed(const Duration(minutes: 1)),
        same(completed),
      );

      expect(empty.currentStepName, '');
      expect(empty.progress, 0);
      expect(empty.preparationStepStates, isEmpty);
      expect(zeroDuration.progress, 0);
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
        baseline.cacheFingerprint,
        isNot(equals(renamed.cacheFingerprint)),
      );
    });

    test('schedule with preparation derives start time and total duration', () {
      expect(schedule.totalDuration, const Duration(minutes: 50));
      expect(schedule.preparationStartTime, DateTime(2026, 3, 20, 9, 10));
      expect(schedule.timeRemainingBeforeLeaving.inMinutes, isA<int>());
      expect(schedule.isLate, isA<bool>());
      expect(schedule.cacheFingerprint, contains('s1:wash:600000:s2|'));
      expect(schedule.cacheFingerprint, contains('s2:dress:600000:|'));
    });

    test(
      'combines a schedule entity with timed preparation preserving fields',
      () {
        final base = ScheduleEntity(
          id: 'schedule-combine',
          place: const PlaceEntity(id: 'p2', placeName: 'Gym'),
          scheduleName: 'Workout',
          scheduleTime: DateTime(2026, 3, 21, 8),
          moveTime: const Duration(minutes: 15),
          isChanged: true,
          isStarted: true,
          scheduleSpareTime: null,
          scheduleNote: 'shoes',
          latenessTime: 3,
          doneStatus: ScheduleDoneStatus.lateEnd,
        );

        final combined =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
              base,
              preparation,
            );

        expect(combined.id, base.id);
        expect(combined.place, base.place);
        expect(combined.scheduleName, base.scheduleName);
        expect(combined.scheduleTime, base.scheduleTime);
        expect(combined.moveTime, base.moveTime);
        expect(combined.isChanged, isTrue);
        expect(combined.isStarted, isTrue);
        expect(combined.scheduleSpareTime, isNull);
        expect(combined.scheduleNote, 'shoes');
        expect(combined.latenessTime, 3);
        expect(combined.doneStatus, ScheduleDoneStatus.lateEnd);
        expect(combined.preparation, preparation);
      },
    );
  });

  group('ScheduleEntity model mapping', () {
    test('maps to and from database models preserving user-visible fields', () {
      final entity = ScheduleEntity.fromScheduleWithPlaceModel(
        ScheduleWithPlace(
          schedule: Schedule(
            id: 'schedule-model',
            placeId: 'place-model',
            scheduleName: 'Doctor',
            scheduleTime: DateTime(2026, 4, 1, 15),
            moveTime: const Duration(minutes: 30),
            isChanged: true,
            isStarted: false,
            scheduleSpareTime: const Duration(minutes: 5),
            scheduleNote: null,
            latenessTime: 7,
          ),
          place: const Place(id: 'place-model', placeName: 'Clinic'),
        ),
      );

      expect(entity.id, 'schedule-model');
      expect(entity.place.placeName, 'Clinic');
      expect(entity.scheduleNote, '');
      expect(entity.doneStatus, ScheduleDoneStatus.notEnded);

      final model = entity
          .copyWith(doneStatus: ScheduleDoneStatus.normalEnd)
          .toScheduleWithPlaceModel();

      expect(model.schedule.id, 'schedule-model');
      expect(model.schedule.placeId, 'place-model');
      expect(model.schedule.scheduleName, 'Doctor');
      expect(model.schedule.moveTime, const Duration(minutes: 30));
      expect(model.schedule.scheduleNote, '');
      expect(model.schedule.latenessTime, 7);
      expect(model.place.placeName, 'Clinic');
    });

    test(
      'string representation includes schedule identity for diagnostics',
      () {
        final entity = ScheduleEntity(
          id: 'schedule-log',
          place: const PlaceEntity(id: 'p1', placeName: 'Office'),
          scheduleName: 'Meeting',
          scheduleTime: DateTime(2026, 5, 1, 9),
          moveTime: const Duration(minutes: 10),
          isChanged: false,
          isStarted: false,
          scheduleSpareTime: null,
          scheduleNote: '',
        );

        expect(entity.toString(), contains('schedule-log'));
        expect(entity.toString(), contains('Meeting'));
      },
    );
  });

  group('ScheduleState timing helper', () {
    test(
      'durationUntilPreparationStartAt uses injected now deterministically',
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
      },
    );
  });
}
