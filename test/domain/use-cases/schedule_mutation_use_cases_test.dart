import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/finish_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/sign_out_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';

void main() {
  test(
    'create and update schedule use cases persist then reconcile alarms',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final reconcile = _FakeReconcileAlarmsUseCase();
      final createUseCase = CreateScheduleWithPlaceUseCase(
        scheduleRepository,
        reconcile,
      );
      final updateUseCase = UpdateScheduleUseCase(
        scheduleRepository,
        reconcile,
      );
      final schedule = _schedule('schedule-1');

      await createUseCase(schedule);
      await updateUseCase(
        schedule.copyWith(doneStatus: ScheduleDoneStatus.lateEnd),
      );
      await pumpEventQueue();

      expect(scheduleRepository.createdSchedules, [schedule]);
      expect(
        scheduleRepository.updatedSchedules.single.doneStatus,
        ScheduleDoneStatus.lateEnd,
      );
      expect(reconcile.callCount, 2);
    },
  );

  test(
    'delete schedule removes schedule, cancels alarm, then reconciles',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final cancel = _FakeCancelScheduleAlarmUseCase();
      final reconcile = _FakeReconcileAlarmsUseCase();
      final useCase = DeleteScheduleUseCase(
        scheduleRepository,
        cancel,
        reconcile,
      );
      final schedule = _schedule('schedule-1');

      await useCase(schedule);
      await pumpEventQueue();

      expect(scheduleRepository.deletedSchedules, [schedule]);
      expect(cancel.cancelledScheduleIds, ['schedule-1']);
      expect(reconcile.callCount, 1);
    },
  );

  test(
    'finish schedule records lateness, cancels alarm, then reconciles',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final cancel = _FakeCancelScheduleAlarmUseCase();
      final reconcile = _FakeReconcileAlarmsUseCase();
      final useCase = FinishScheduleUseCase(
        scheduleRepository,
        cancel,
        reconcile,
      );

      await useCase('schedule-1', 12);
      await pumpEventQueue();

      expect(scheduleRepository.finishedSchedules, [('schedule-1', 12)]);
      expect(cancel.cancelledScheduleIds, ['schedule-1']);
      expect(reconcile.callCount, 1);
    },
  );

  test(
    'sign out clears registered alarms before clearing user session',
    () async {
      final userRepository = _FakeUserRepository();
      final cancelAll = _FakeCancelAllAlarmsUseCase();
      final useCase = SignOutUseCase(userRepository, cancelAll);

      await useCase();

      expect(cancelAll.unregisterDeviceRequests, [true]);
      expect(userRepository.signOutCount, 1);
    },
  );
}

ScheduleEntity _schedule(String id) {
  return ScheduleEntity(
    id: id,
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Meeting',
    scheduleTime: DateTime(2026, 5, 15, 9),
    moveTime: const Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 5),
    scheduleNote: '',
  );
}

class _FakeScheduleRepository implements ScheduleRepository {
  final createdSchedules = <ScheduleEntity>[];
  final updatedSchedules = <ScheduleEntity>[];
  final deletedSchedules = <ScheduleEntity>[];
  final finishedSchedules = <(String, int)>[];

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream => const Stream.empty();

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {
    createdSchedules.add(schedule);
  }

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {
    deletedSchedules.add(schedule);
  }

  @override
  Future<void> finishSchedule(String scheduleId, int latenessTime) async {
    finishedSchedules.add((scheduleId, latenessTime));
  }

  @override
  Future<ScheduleEntity> getScheduleById(String id) async => _schedule(id);

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async => const [];

  @override
  Future<void> updateSchedule(
    ScheduleEntity schedule, {
    bool includePreparationSource = false,
  }) async {
    updatedSchedules.add(schedule);
  }
}

class _FakeCancelScheduleAlarmUseCase implements CancelScheduleAlarmUseCase {
  final cancelledScheduleIds = <String>[];

  @override
  Future<void> call(String scheduleId) async {
    cancelledScheduleIds.add(scheduleId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCancelAllAlarmsUseCase implements CancelAllAlarmsUseCase {
  final unregisterDeviceRequests = <bool>[];

  @override
  Future<void> call({bool unregisterDevice = false}) async {
    unregisterDeviceRequests.add(unregisterDevice);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReconcileAlarmsUseCase implements ReconcileAlarmsUseCase {
  int callCount = 0;

  @override
  Future<AlarmReconciliationResult> call() async {
    callCount += 1;
    return AlarmReconciliationResult(
      status: AlarmReconciliationStatus.armed,
      nativeAlarmProvider: AlarmProvider.none,
      fallbackProvider: AlarmProvider.localNotification,
      armedScheduleIds: const [],
      skippedScheduleCount: 0,
      failures: const [],
      scheduleWindowStart: DateTime.utc(2026, 5, 15),
      scheduleWindowEnd: DateTime.utc(2026, 5, 23),
      alarmCoverageStart: DateTime.utc(2026, 5, 15),
      alarmCoverageEnd: DateTime.utc(2026, 5, 22),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRepository implements UserRepository {
  int signOutCount = 0;

  @override
  Stream<UserEntity> get userStream => const Stream.empty();

  @override
  Future<void> signOut() async {
    signOutCount += 1;
  }

  @override
  Future<void> deleteAppleUser({String? feedbackMessage}) async {}

  @override
  Future<void> deleteGoogleUser({String? feedbackMessage}) async {}

  @override
  Future<void> deleteUser({String? feedbackMessage}) async {}

  @override
  Future<void> disconnectGoogleSignIn() async {}

  @override
  Future<void> getUser() async {}

  @override
  Future<String?> getUserSocialType() async => null;

  @override
  Future<void> postFeedback(String message) async {}

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithApple({
    required String idToken,
    required String authCode,
    required String fullName,
    String? email,
  }) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {}

  @override
  Future<void> signInWithGoogle(GoogleSignInAccount account) async {}

  @override
  Future<void> initializeGoogleSignIn() async {}

  @override
  bool get supportsGoogleAuthenticate => false;

  @override
  Stream<GoogleSignInAuthenticationEvent> get googleAuthenticationEvents =>
      const Stream.empty();

  @override
  Future<GoogleSignInAccount> authenticateWithGoogle() async {
    throw UnimplementedError();
  }
}
