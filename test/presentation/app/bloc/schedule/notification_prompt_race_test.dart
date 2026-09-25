import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import '../../../../core/services/notification_tap_router_test.dart'
    show tapSchedule;

void main() {
  for (final oldEvent in [
    'null-nearest',
    'past-nearest',
    'legacy-lookup',
    'legacy-restore',
  ]) {
    test(
      'late $oldEvent handler cannot overwrite a newer notification owner',
      () async {
        final session = _Session();
        final navigation = _Navigation();
        final bloc = ScheduleBloc.test(_Nearest(), navigation, session);
        final old = Object();
        bloc.presentNotificationPrompt(tapSchedule('old'), old, () => true);
        await pumpEventQueue();
        bloc.releaseNotificationPrompt(old, resumeNearest: false);
        if (oldEvent == 'null-nearest') {
          bloc.add(const ScheduleUpcomingReceived(null));
        } else if (oldEvent == 'past-nearest') {
          // Null and past take the same clearing branch, but past has its own ID.
          final past = tapSchedule('past');
          final pastSchedule = ScheduleWithPreparationEntity(
            id: past.id,
            place: past.place,
            scheduleName: past.scheduleName,
            scheduleTime: DateTime.utc(2000),
            occurrenceOffsetSeconds: 0,
            moveTime: past.moveTime,
            isChanged: false,
            isStarted: false,
            scheduleSpareTime: Duration.zero,
            scheduleNote: '',
            preparation: past.preparation,
          );
          bloc.add(ScheduleUpcomingReceived(pastSchedule));
        } else {
          session.waitLookup = oldEvent == 'legacy-lookup';
          bloc.add(const ScheduleAlarmPromptRequested(scheduleId: 'old'));
        }
        await pumpEventQueue();
        expect(session.entered, isTrue);
        final newOwner = Object();
        bloc.presentNotificationPrompt(tapSchedule('B'), newOwner, () => true);
        await pumpEventQueue();
        expect(bloc.state.schedule?.id, 'B');
        session.release.complete();
        await pumpEventQueue();
        expect(bloc.state.schedule?.id, 'B');
        expect(bloc.ownsNotificationPrompt(newOwner), isTrue);
        expect(navigation.routes, isEmpty);
        expect(session.starts, 0);
        await bloc.close();
      },
    );
  }
}

class _Nearest implements GetNearestUpcomingScheduleUseCase {
  @override
  Stream<NearestScheduleQuery> call({required NearestQueryKey key}) =>
      const Stream.empty();
  @override
  Future<ScheduleWithPreparationEntity?> readActive() async => null;
}

class _Navigation extends NavigationService {
  final routes = <String>[];
  @override
  void go(String routeName, {Object? extra}) => routes.add(routeName);
  @override
  void push(String routeName, {Object? extra}) => routes.add(routeName);
}

class _Session implements SchedulePreparationSessionUseCase {
  final release = Completer<void>();
  bool waitLookup = false, entered = false;
  int starts = 0;
  @override
  Future<void> clearPersistedState(String id) async {
    entered = true;
    await release.future;
  }

  @override
  Future<SchedulePreparationPromptResult> resolvePromptedSchedule({
    required String scheduleId,
    required bool startPreparation,
    String? scheduleFingerprint,
    bool Function()? isCurrent,
  }) async {
    if (waitLookup) {
      entered = true;
      await release.future;
    }
    return SchedulePreparationPromptResult.ready(tapSchedule('old'));
  }

  @override
  Future<ScheduleWithPreparationEntity> restoreTimedPreparationIfValid(
    ScheduleWithPreparationEntity schedule, {
    required DateTime now,
    RestoredSessionCallback? onRestoredSession,
    void Function()? onInvalidated,
  }) async {
    entered = true;
    await release.future;
    onRestoredSession?.call(startedAt: DateTime(2020), actionEvents: []);
    return schedule;
  }

  @override
  Future<DateTime> startSchedulePreparation(
    String id, {
    bool Function()? isCurrent,
    String? expectedFingerprint,
  }) async {
    starts++;

    return DateTime.now().toUtc();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
