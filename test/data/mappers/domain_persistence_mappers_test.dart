import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  group('domain persistence mappers', () {
    test(
      'map schedules to and from database rows preserving stored fields',
      () {
        final entity = ScheduleWithPlace(
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
        ).toScheduleEntity();

        expect(entity.id, 'schedule-model');
        expect(entity.place.placeName, 'Clinic');
        expect(entity.scheduleNote, '');
        expect(entity.doneStatus, ScheduleDoneStatus.notEnded);

        final row = entity
            .copyWith(doneStatus: ScheduleDoneStatus.normalEnd)
            .toScheduleWithPlaceRow();

        expect(row.schedule.id, 'schedule-model');
        expect(row.schedule.placeId, 'place-model');
        expect(row.schedule.scheduleName, 'Doctor');
        expect(row.schedule.moveTime, const Duration(minutes: 30));
        expect(row.schedule.scheduleNote, '');
        expect(row.schedule.latenessTime, 7);
        expect(row.place.placeName, 'Clinic');
      },
    );

    test('maps users to and from database rows preserving profile values', () {
      const row = User(
        id: 'user-1',
        email: 'user@example.com',
        name: 'User',
        spareTime: 12,
        note: 'note',
        score: 4.5,
      );

      final entity = row.toUserEntity();
      final roundTrip = entity.toUserRow();

      expect(entity.valueOrNull, entity);
      expect(entity.spareTimeOrNull, const Duration(minutes: 12));
      expect(entity.scoreOrNull, 4.5);
      expect(entity.nameOrNull, 'User');
      expect(entity.emailOrNull, 'user@example.com');
      expect(roundTrip.id, row.id);
      expect(roundTrip.email, row.email);
      expect(roundTrip.name, row.name);
      expect(roundTrip.spareTime, row.spareTime);
      expect(roundTrip.note, row.note);
      expect(roundTrip.score, row.score);
    });

    test('empty users cannot be converted to database rows', () {
      const entity = UserEntity.empty();

      expect(entity.toUserRow, throwsException);
    });

    test('maps places and preparation steps to database rows', () {
      const place = PlaceEntity(id: 'place-1', placeName: 'Office');
      const step = PreparationStepEntity(
        id: 'step-1',
        preparationName: 'Pack',
        preparationTime: Duration(minutes: 8),
        nextPreparationId: 'step-2',
      );

      final placeRow = place.toPlaceRow();
      final userStepRow = step.toPreparationUserRow('user-1');
      final scheduleStepRow = step.toPreparationScheduleRow('schedule-1');

      expect(placeRow.toPlaceEntity(), place);
      expect(userStepRow.userId, 'user-1');
      expect(userStepRow.preparationTime, 8);
      expect(userStepRow.nextPreparationId, 'step-2');
      expect(scheduleStepRow.scheduleId, 'schedule-1');
      expect(scheduleStepRow.preparationName, 'Pack');
    });
  });
}
