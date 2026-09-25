import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import '../../../alarm/screens/preparation_flow_widget_test.dart'
    show
        buildSchedule,
        StubGetNearestUpcomingScheduleUseCase,
        SpyNavigationService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'partial start survives same-run emissions; timer and skip retain memory until one explicit retry',
    () async {
      final now = DateTime.utc(2026, 10);
      final schedule = buildSchedule(
        id: 'partial',
        scheduleTime: now.add(const Duration(hours: 2)),
        steps: const [
          PreparationStepWithTimeEntity(
            id: 'one',
            preparationName: 'one',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: 'two',
          ),
          PreparationStepWithTimeEntity(
            id: 'two',
            preparationName: 'two',
            preparationTime: Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      );
      final session = _Session();
      final bloc = ScheduleBloc.test(
        StubGetNearestUpcomingScheduleUseCase(() => const Stream.empty()),
        SpyNavigationService(),
        session,
        nowProvider: () => now,
      );
      addTearDown(bloc.close);
      final prompt = Object();
      bloc.presentNotificationPrompt(schedule, prompt, () => true);
      await Future<void>.delayed(Duration.zero);
      await bloc.requestPreparationStart(isCurrent: () => true);
      bloc.confirmNotificationPrompt(prompt);
      // Release selected-view ownership so a genuine repository emission reaches
      // the same-run pending recovery guard.
      final owner = bloc.notificationPreparationOwner!;
      final view = Object();
      bloc.attachNotificationPreparation(owner, view);
      bloc.releaseNotificationPreparation(owner, view);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.hasPendingStartRecovery, isTrue);
      bloc.add(ScheduleUpcomingReceived(schedule));
      bloc.add(const ScheduleStepSkipped());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.hasPendingStartRecovery, isTrue);
      expect(session.persistAttempts, 0);
      expect(session.events.single.stepId, 'one');
      expect(session.starts, 1);
      session.barrier = Completer<void>();
      bloc.add(const SchedulePreparationRecoveryRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isRecoveringStart, isTrue);
      bloc.add(const SchedulePreparationRecoveryRequested());
      await Future<void>.delayed(Duration.zero);
      expect(session.starts, 2);
      session.barrier!.completeError(StateError('still unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isRecoveringStart, isFalse);
      expect(bloc.state.hasPendingStartRecovery, isTrue);
      session.barrier = null;
      session.partial = false;
      bloc.add(const SchedulePreparationRecoveryRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.hasPendingStartRecovery, isFalse);
      expect(session.starts, 3);
      expect(session.events.single.stepId, 'one');
    },
  );
}

class _Session implements SchedulePreparationSessionUseCase {
  bool partial = true;
  int starts = 0;
  int persistAttempts = 0;
  Completer<void>? barrier;
  List<PreparationActionEventEntity> events = [];
  @override
  Future<PreparationStartReceipt> startEarlySession(
    ScheduleWithPreparationEntity schedule, {
    required DateTime startedAt,
    bool Function()? isCurrent,
  }) async {
    starts++;
    await barrier?.future;
    return PreparationStartReceipt(
      startedAt: startedAt,
      hasPendingRecovery: partial,
      actionEvents: events,
    );
  }

  @override
  Future<void> saveTimedPreparationSnapshot(
    ScheduleWithPreparationEntity schedule, {
    DateTime? savedAt,
    DateTime? startedAt,
    List<PreparationActionEventEntity> actionEvents = const [],
    bool persist = true,
  }) async {
    events = actionEvents;
    if (persist) persistAttempts++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
