import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/finish_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';
import 'package:on_time_front/domain/use-cases/sign_out_use_case.dart';
import 'package:on_time_front/domain/use-cases/start_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';

void main() {
  test(
    'create and update schedule use cases persist then request alarm effects',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final alarmEffects = _FakeScheduleMutationAlarmEffectsCoordinator();
      final createUseCase = CreateScheduleWithPlaceUseCase(
        scheduleRepository,
        alarmEffects,
      );
      final updateUseCase = UpdateScheduleUseCase(
        scheduleRepository,
        alarmEffects,
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
      expect(alarmEffects.calls, ['created:schedule-1', 'updated:schedule-1']);
    },
  );

  test(
    'create and update schedule use cases skip alarm effects on repository failure',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final alarmEffects = _FakeScheduleMutationAlarmEffectsCoordinator();
      final createUseCase = CreateScheduleWithPlaceUseCase(
        scheduleRepository,
        alarmEffects,
      );
      final updateUseCase = UpdateScheduleUseCase(
        scheduleRepository,
        alarmEffects,
      );
      final schedule = _schedule('schedule-1');

      scheduleRepository.failCreate = true;
      await expectLater(createUseCase(schedule), throwsException);

      scheduleRepository.failCreate = false;
      scheduleRepository.failUpdate = true;
      await expectLater(updateUseCase(schedule), throwsException);

      expect(alarmEffects.calls, isEmpty);
    },
  );

  test(
    'delete schedule removes schedule then requests deleted alarm effects',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final alarmEffects = _FakeScheduleMutationAlarmEffectsCoordinator();
      final useCase = DeleteScheduleUseCase(scheduleRepository, alarmEffects);
      final schedule = _schedule('schedule-1');

      await useCase(schedule);

      expect(scheduleRepository.deletedSchedules, [schedule]);
      expect(alarmEffects.calls, ['deleted:schedule-1']);
    },
  );

  test(
    'finish schedule records lateness then requests finished alarm effects',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final alarmEffects = _FakeScheduleMutationAlarmEffectsCoordinator();
      final useCase = FinishScheduleUseCase(scheduleRepository, alarmEffects);

      await useCase('schedule-1', 12);

      expect(scheduleRepository.finishedSchedules, [('schedule-1', 12)]);
      expect(scheduleRepository.startedScheduleIds, ['schedule-1']);
      expect(alarmEffects.calls, ['finished:schedule-1']);
    },
  );

  test(
    'start schedule marks a preparation session on the repository',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final useCase = StartScheduleUseCase(scheduleRepository);

      await useCase('schedule-1');

      expect(scheduleRepository.startedScheduleIds, ['schedule-1']);
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
  final startedScheduleIds = <String>[];
  final finishedSchedules = <(String, int)>[];
  bool failCreate = false;
  bool failUpdate = false;

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream => const Stream.empty();

  @override
  Stream<List<ScheduleEntity>> watchSchedulesByDate(
    DateTime startDate,
    DateTime endDate,
  ) => const Stream.empty();

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {
    if (failCreate) {
      throw Exception('create failed');
    }
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
  Future<void> startSchedule(String scheduleId) async {
    startedScheduleIds.add(scheduleId);
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
    if (failUpdate) {
      throw Exception('update failed');
    }
    updatedSchedules.add(schedule);
  }
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

class _FakeScheduleMutationAlarmEffectsCoordinator
    implements ScheduleMutationAlarmEffectsCoordinator {
  final calls = <String>[];

  @override
  Future<void> call({
    required ScheduleMutationAlarmOperation operation,
    required String scheduleId,
  }) async {
    calls.add('${operation.name}:$scheduleId');
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
