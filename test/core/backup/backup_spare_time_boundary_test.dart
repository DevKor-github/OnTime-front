import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'backup_validated_ingestion_test.dart' show validate;
import 'backup_validation_contract_test.dart' show validBackup;

void main() {
  for (final spare in <int?>[null, 60]) {
    test(
      'year-one appointment spare=$spare uses its own lead without profile fallback overflow',
      () async {
        final input =
            jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
        input['profile']['spareTimeMinutes'] = 0x7fffffffffffffff ~/ 60000000;
        input['schedules'][0].addAll({
          'civilTime': '0001-01-01T00:00:00.000',
          'timeZoneId': 'UTC',
          'occurrenceOffsetSeconds': 0,
          'spareTimeMinutes': spare,
        });
        if (spare != null) {
          await expectLater(
            validate(input),
            throwsA(
              isA<BackupProcessingFailure>().having(
                (e) => e.kind,
                'genuine appointment lead underflow',
                BackupFailureKind.dataInvariant,
              ),
            ),
          );
          return;
        }
        final data = await validate(input);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await data.materialize(db, pendingCleanup: false);
        await data.validateReadBack(db, pendingCleanup: false);
        final schedule = await db.select(db.schedules).getSingle();
        expect(schedule.scheduleSpareTime, isNull);
        expect(schedule.scheduleTime, DateTime.utc(1));
        expect(
          (await db.select(db.users).getSingle()).spareTime,
          0x7fffffffffffffff ~/ 60000000,
        );
      },
    );
  }
  test(
    'profile own duration limit remains enforced even if no appointment inherits it',
    () async {
      final input =
          jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
      input['profile']['spareTimeMinutes'] =
          (0x7fffffffffffffff ~/ 60000000) + 1;
      input['schedules'][0]['spareTimeMinutes'] = null;
      await expectLater(
        validate(input),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'profile duration limit',
            BackupFailureKind.dataInvariant,
          ),
        ),
      );
    },
  );
}
