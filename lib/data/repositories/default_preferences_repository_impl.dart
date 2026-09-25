import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/validation/local_input_limits.dart';
import 'package:on_time_front/domain/entities/default_preferences.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/default_preferences_repository.dart';

@Injectable(as: DefaultPreferencesRepository)
class DefaultPreferencesRepositoryImpl implements DefaultPreferencesRepository {
  DefaultPreferencesRepositoryImpl(
    this.db, {
    @ignoreParam LocalDataOperationGate? gate,
  }) : gate = gate ?? LocalDataOperationGate.shared;
  final AppDatabase db;
  final LocalDataOperationGate gate;

  @override
  bool isGenerationCurrent(int generation) =>
      generation == gate.generation &&
      !gate.isReplacingData &&
      !gate.isRecoveryPending &&
      !gate.isInvalidated;

  Future<User> _profile() async {
    final row = await (db.select(
      db.users,
    )..where((u) => u.id.equals(localProfileId))).getSingleOrNull();
    if (row?.storeIncarnation == null || row!.restoreCleanupPending) {
      throw const DefaultPreferencesRejected(
        DefaultPreferencesFailure.unavailable,
      );
    }
    return row;
  }

  @override
  Future<DefaultPreferencesSnapshot> read() async {
    final generation = gate.captureWrite();
    return db.transaction(() async {
      gate.checkWrite(generation);
      final user = await _profile();
      final preparation = await db.preparationUserDao
          .getPreparationUsersByUserId(localProfileId);
      gate.checkWrite(generation);
      return DefaultPreferencesSnapshot(
        preparation: PreparationEntity(
          preparationStepList: List.unmodifiable(
            preparation.preparationStepList,
          ),
        ),
        spareTime: Duration(minutes: user.spareTime),
        store: user.storeIncarnation!,
        generation: generation,
        revision: user.dataRevision,
      );
    });
  }

  @override
  int get generation => gate.generation;

  @override
  Future<DefaultPreferencesAuthority> authority(
    DefaultPreferencesSaveReceipt receipt,
  ) async {
    if (receipt.generation != gate.generation) {
      return DefaultPreferencesAuthority.superseded;
    }
    if (!isGenerationCurrent(receipt.generation)) {
      return DefaultPreferencesAuthority.unavailable;
    }
    try {
      final row = await (db.select(
        db.users,
      )..where((u) => u.id.equals(localProfileId))).getSingleOrNull();
      if (receipt.generation != gate.generation) {
        return DefaultPreferencesAuthority.superseded;
      }
      if (!isGenerationCurrent(receipt.generation) ||
          row == null ||
          row.restoreCleanupPending ||
          row.storeIncarnation == null) {
        return DefaultPreferencesAuthority.unavailable;
      }
      return row.storeIncarnation == receipt.store
          ? DefaultPreferencesAuthority.current
          : DefaultPreferencesAuthority.superseded;
    } catch (_) {
      return receipt.generation != gate.generation
          ? DefaultPreferencesAuthority.superseded
          : DefaultPreferencesAuthority.unavailable;
    }
  }

  @override
  Future<DefaultPreferencesSaveReceipt> save(
    DefaultPreferencesSubmission input,
  ) async {
    _validate(input);
    try {
      return await db.writeTransaction(() async {
        gate.checkWrite(input.baseline.generation);
        final row = await _profile();
        if (row.storeIncarnation != input.baseline.store ||
            row.dataRevision != input.baseline.revision) {
          throw const DefaultPreferencesRejected(
            DefaultPreferencesFailure.conflict,
          );
        }
        final current = await db.preparationUserDao.getPreparationUsersByUserId(
          localProfileId,
        );
        final preparationChanged = !_same(current, input.preparation);
        final spareChanged = row.spareTime != input.spareTime.inMinutes;
        final changed = preparationChanged || spareChanged;
        if (preparationChanged) {
          await db.preparationUserDao.createPreparationUser(
            input.preparation.ordered,
            localProfileId,
          );
        }
        if (spareChanged) {
          // This aggregate owns the one durable revision for both preferences.
          await (db.update(
            db.users,
          )..where((u) => u.id.equals(localProfileId))).write(
            UsersCompanion(spareTime: Value(input.spareTime.inMinutes)),
          );
        }
        if (changed) await db.userDao.markDurableDataChanged(localProfileId);
        return DefaultPreferencesSaveReceipt(
          operation: Object(),
          store: row.storeIncarnation!,
          generation: input.baseline.generation,
          changed: changed,
          revision: row.dataRevision + (changed ? 1 : 0),
          reloadPending: changed,
          deliveryPending: changed,
        );
      }, gate: gate);
    } on DefaultPreferencesRejected {
      rethrow;
    } on LocalDataUnavailable {
      throw const DefaultPreferencesRejected(
        DefaultPreferencesFailure.unavailable,
      );
    } catch (_) {
      throw const DefaultPreferencesRejected(DefaultPreferencesFailure.failed);
    }
  }

  bool _same(PreparationEntity a, PreparationEntity b) {
    final left = a.ordered.preparationStepList;
    final right = b.ordered.preparationStepList;
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id ||
          left[i].preparationName != right[i].preparationName ||
          left[i].preparationTime != right[i].preparationTime) {
        return false;
      }
    }
    return true;
  }

  void _validate(DefaultPreferencesSubmission input) {
    Never invalid() => throw const DefaultPreferencesRejected(
      DefaultPreferencesFailure.invalid,
    );
    final spare = input.spareTime;
    if (spare.isNegative ||
        spare.inMinutes > LocalInputLimits.maxMinuteValue ||
        spare.inMicroseconds % Duration.microsecondsPerMinute != 0) {
      invalid();
    }
    final steps = input.preparation.preparationStepList;
    final byId = {for (final step in steps) step.id: step};
    if (byId.length != steps.length) invalid();
    final targets = <String>{};
    for (final step in steps) {
      if (step.id.isEmpty ||
          step.preparationName.trim().isEmpty ||
          step.preparationName.length > 30 ||
          step.preparationTime.inMinutes < 1 ||
          step.preparationTime.inMinutes > LocalInputLimits.maxMinuteValue ||
          step.preparationTime.inMicroseconds %
                  Duration.microsecondsPerMinute !=
              0) {
        invalid();
      }
      if (step.nextPreparationId != null &&
          (!byId.containsKey(step.nextPreparationId) ||
              !targets.add(step.nextPreparationId!))) {
        invalid();
      }
      final seen = <String>{};
      var current = step;
      while (true) {
        if (!seen.add(current.id)) invalid();
        if (current.nextPreparationId == null) break;
        final next = byId[current.nextPreparationId];
        if (next == null) invalid();
        current = next;
      }
    }
    if (targets.isNotEmpty && targets.length != steps.length - 1) invalid();
  }
}
