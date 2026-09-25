import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_content.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import '../../helpers/schedule_deletion_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ScheduleDeletionFixture f;
  setUp(() async {
    f = ScheduleDeletionFixture();
    await f.initialize();
  });
  tearDown(() => f.close());

  test(
    'new exported content omits deleted history while old external bytes remain restorable',
    () async {
      await f.create('private-history');
      await f.create('retained-history');
      await f.outcome('private-history', ScheduleDoneStatus.normalEnd);
      await f.outcome('retained-history', ScheduleDoneStatus.lateEnd);
      await f.db.preparationUserDao.createPreparationUser(
        f.preparation('shared-default'),
        'local-profile',
      );
      await f.db.preparationTemplateDao.put(
        id: 'shared-template',
        name: 'Independent template',
        preparation: f.preparation('shared-template'),
        now: f.now,
      );
      f.now = DateTime.utc(2031);
      final before = await f.exportBytes();
      final directory = await Directory.systemTemp.createTemp(
        'ontime-u01-external-',
      );
      addTearDown(() => directory.delete(recursive: true));
      // Portable plaintext snapshot fixture; no claim this is an encrypted file.
      final external = File('${directory.path}/old-snapshot.json');
      await external.writeAsBytes(before, flush: true);
      final oldHash = sha256.convert(await external.readAsBytes());
      final score = await f.score();

      await f.aggregate.delete(
        await f.aggregate.readForDeletion('private-history'),
      );
      final after = await f.exportBytes();
      final text = utf8.decode(after);
      final decoded = BackupContent.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );

      for (final sentinel in [
        'private-history',
        'Name private-history',
        'Note private-history',
        'private-history first',
        'private-history last',
      ]) {
        expect(
          text,
          isNot(contains(sentinel)),
          reason: 'Deleted owned content must not enter a new backup',
        );
      }
      expect(decoded.schedules.map((s) => s.id), ['retained-history']);
      expect(decoded.profile.valueOrNull!.eligibleOutcomeCount, score.eligible);
      expect(decoded.profile.valueOrNull!.onTimeOutcomeCount, score.onTime);
      expect(
        decoded.defaultPreparation.preparationStepList.map(
          (s) => s.preparationName,
        ),
        contains('shared-default first'),
      );
      expect(decoded.templates.single.id, 'shared-template');
      expect(sha256.convert(await external.readAsBytes()), oldHash);
      expect(await external.readAsBytes(), before);

      final restored = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(restored.close);
      final old = BackupContent.fromJson(
        jsonDecode(utf8.decode(await external.readAsBytes()))
            as Map<String, dynamic>,
      );
      await old.writeTo(restored, pendingCleanup: false);
      await old.validateReadBack(restored);
      expect(
        (await restored.scheduleDao.getScheduleById(
          'private-history',
        )).schedule.scheduleName,
        'Name private-history',
      );
      expect((await f.db.select(f.db.schedules).get()).map((s) => s.id), [
        'retained-history',
      ]);
    },
  );

  test(
    'deleted recurring override vanishes from portable definitions without losing shared rule or exclusion',
    () async {
      final at = DateTime.utc(2030, 1, 2, 10);
      await f.recurring.create(
        f.schedule('shared-series', at: at),
        f.preparation('shared-rule'),
        RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: at,
          timeZoneId: 'UTC',
          count: 2,
        ),
      );
      final target = (await f.db.scheduleDao.getScheduleList()).first
          .toScheduleEntity();
      await f.recurring.updateOccurrence(
        target,
        target.copyWith(
          scheduleName: 'Private title',
          scheduleNote: 'Private note',
        ),
        f.preparation('private-override'),
        preparationChanged: true,
      );
      final edited = (await f.db.scheduleDao.getScheduleById(
        target.id,
      )).toScheduleEntity();
      final ownedDefinition = edited.preparationDefinitionId!;
      await f.outcome(edited.id, ScheduleDoneStatus.abnormalEnd);
      f.now = DateTime.utc(2031);
      final before = utf8.decode(await f.exportBytes());
      expect(before, contains('private-override first'));
      expect(before, contains(ownedDefinition));

      await f.aggregate.delete(await f.aggregate.readForDeletion(edited.id));
      final text = utf8.decode(await f.exportBytes());
      final content = BackupContent.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );

      for (final sentinel in [
        edited.id,
        ownedDefinition,
        'Private title',
        'Private note',
        'private-override first',
        'private-override last',
      ]) {
        expect(text, isNot(contains(sentinel)));
      }
      expect(content.recurring.segments, hasLength(1));
      expect(content.recurring.definitions, hasLength(1));
      expect(
        content.recurring.steps.map((s) => s.name),
        contains('shared-rule first'),
      );
      expect(content.recurring.exclusions, hasLength(1));
      final exclusion = content.recurring.exclusions.single;
      expect(exclusion.segmentId, edited.recurringSegmentId);
      expect(exclusion.slotKey, edited.recurringSlotKey);
      expect(exclusion.ordinal, edited.recurringOrdinal);
      expect(content.schedules, hasLength(1));
      final roundTrip = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(roundTrip.close);
      await content.writeTo(roundTrip, pendingCleanup: false);
      await content.validateReadBack(roundTrip);
    },
  );
}
