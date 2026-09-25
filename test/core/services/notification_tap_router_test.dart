import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';

final _scheduleTime = DateTime.now().add(const Duration(hours: 1));
String tapPayload(String id) =>
    jsonEncode({'type': 'schedule_notification', 'scheduleId': id});
ScheduleWithPreparationEntity tapSchedule(String id) =>
    ScheduleWithPreparationEntity(
      id: id,
      place: const PlaceEntity(id: 'place', placeName: 'Office'),
      scheduleName: 'Schedule $id',
      scheduleTime: _scheduleTime.toUtc(),
      occurrenceOffsetSeconds: 0,
      moveTime: Duration.zero,
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: Duration.zero,
      scheduleNote: '',
      preparation: PreparationWithTimeEntity(
        preparationStepList: [
          PreparationStepWithTimeEntity(
            id: 'step-$id',
            preparationName: 'Prepare $id',
            preparationTime: const Duration(minutes: 10),
            nextPreparationId: null,
          ),
        ],
      ),
    );

void main() {
  late _Navigation navigation;
  late NavigationNotificationTapRouter router;
  late LocalDataOperationGate gate;
  late bool ready;
  late List<String> resolved;
  late ResolveNotificationPrompt resolve;
  setUp(() {
    navigation = _Navigation();
    gate = LocalDataOperationGate();
    router = NavigationNotificationTapRouter(navigation);
    ready = false;
    resolved = [];
    resolve = (id, current) async {
      resolved.add(id);
      return SchedulePreparationPromptResult.ready(tapSchedule(id));
    };
    router.configure(
      isReady: () => ready,
      resolve: (id, current) => resolve(id, current),
      dataGate: gate,
    );
  });
  tearDown(() {
    router.detach();
    gate.dispose();
  });

  test(
    'cold same-ID old and legacy payloads are rejected without attaching current identity',
    () async {
      final authority = RestoreRuntimeIdentity.shared;
      final oldIdentity = authority.storeIncarnation,
          oldReject = authority.rejectLegacy,
          oldPending = authority.pending;
      addTearDown(() {
        authority.storeIncarnation = oldIdentity;
        authority.rejectLegacy = oldReject;
        authority.pending = oldPending;
      });
      authority.storeIncarnation = '22222222-2222-2222-2222-222222222222';
      authority.rejectLegacy = true;
      authority.pending = false;
      ready = true;
      router.routeLocalNotificationTap(tapPayload('same'));
      router.routeNativeNotificationTap({
        'type': 'schedule_alarm',
        'scheduleId': 'same',
        'storeIncarnation': '11111111-1111-1111-1111-111111111111',
      });
      await pumpEventQueue();
      expect(resolved, isEmpty);
      expect(navigation.data, isEmpty);
      router.routeLocalNotificationTap(
        jsonEncode({
          'type': 'schedule_notification',
          'scheduleId': 'same',
          'storeIncarnation': authority.storeIncarnation,
        }),
      );
      await pumpEventQueue();
      expect(resolved, ['same']);
      expect(navigation.data.single.schedule.id, 'same');
    },
  );
  test(
    'last valid tap survives delayed readiness and malformed input',
    () async {
      router.routeLocalNotificationTap(tapPayload('A'));
      router.routeLocalNotificationTap(tapPayload('B'));
      for (final raw in [
        null,
        'bad',
        '[]',
        '{}',
        '{"type":"unknown","scheduleId":"bad"}',
        '{"type":"schedule_notification","scheduleId":""}',
      ]) {
        router.routeLocalNotificationTap(raw);
      }
      await pumpEventQueue();
      expect(navigation.extras, isEmpty);
      ready = true;
      router.retry();
      await pumpEventQueue();
      expect(resolved, ['B']);
      expect(navigation.data.single.schedule.id, 'B');
      expect(
        navigation.data.single.payload.keys,
        isNot(contains('scheduleFingerprint')),
      );
    },
  );

  test(
    'queued inflight and open duplicates collapse; later separate tap works',
    () async {
      final result = Completer<SchedulePreparationPromptResult>();
      resolve = (_, _) => result.future;
      ready = true;
      router.routeLocalNotificationTap(tapPayload('A'));
      router.routeLocalNotificationTap(tapPayload('A'));
      router.routeNativeNotificationTap({
        'type': 'schedule_alarm',
        'scheduleId': 'A',
      });
      result.complete(SchedulePreparationPromptResult.ready(tapSchedule('A')));
      await pumpEventQueue();
      router.routeLocalNotificationTap(tapPayload('A'));
      await pumpEventQueue();
      expect(navigation.data, hasLength(1));
      navigation.data.single.onClosed();
      router.routeLocalNotificationTap(tapPayload('A'));
      await pumpEventQueue();
      expect(navigation.data, hasLength(2));
    },
  );

  test(
    'late initial response cannot overwrite newer callback or native tap',
    () async {
      final initialReceipt = router.receipt;
      router.routeNativeNotificationTap({
        'type': 'schedule_alarm',
        'scheduleId': 'B',
      });
      router.receiveInitial(tapPayload('A'), initialReceipt);
      ready = true;
      router.retry();
      await pumpEventQueue();
      expect(navigation.data.single.schedule.id, 'B');
    },
  );

  test(
    'duplicate native receipt blocks stale cold result without invalidating open A',
    () async {
      ready = true;
      router.routeLocalNotificationTap(tapPayload('A'));
      await pumpEventQueue();
      final captured = router.receipt;
      router.routeNativeNotificationTap({
        'type': 'schedule_alarm',
        'scheduleId': 'A',
      });
      router.receiveInitial(tapPayload('B'), captured);
      await pumpEventQueue();
      expect(navigation.data, hasLength(1));
      expect(navigation.data.single.isCurrent(), isTrue);
    },
  );

  test('newer B invalidates an in-flight A validation', () async {
    final a = Completer<SchedulePreparationPromptResult>();
    resolve = (id, _) async => id == 'A'
        ? a.future
        : SchedulePreparationPromptResult.ready(tapSchedule(id));
    ready = true;
    router.routeLocalNotificationTap(tapPayload('A'));
    router.routeLocalNotificationTap(tapPayload('B'));
    a.complete(SchedulePreparationPromptResult.ready(tapSchedule('A')));
    await pumpEventQueue();
    expect(navigation.data.single.schedule.id, 'B');
  });

  test(
    'A in flight then B then A uses latest A rather than stale-key dedupe',
    () async {
      final first = Completer<SchedulePreparationPromptResult>();
      var count = 0;
      resolve = (id, _) async {
        resolved.add(id);
        if (++count == 1) return first.future;
        return SchedulePreparationPromptResult.ready(tapSchedule(id));
      };
      ready = true;
      router.routeLocalNotificationTap(tapPayload('A'));
      router.routeLocalNotificationTap(tapPayload('B'));
      router.routeLocalNotificationTap(tapPayload('A'));
      first.complete(SchedulePreparationPromptResult.ready(tapSchedule('A')));
      await pumpEventQueue();
      expect(resolved, ['A', 'A']);
      expect(navigation.data.single.schedule.id, 'A');
    },
  );

  test(
    'new-generation A is accepted while old-generation A lookup still waits',
    () async {
      final first = Completer<SchedulePreparationPromptResult>();
      var count = 0;
      resolve = (id, _) async {
        if (++count == 1) return first.future;
        return SchedulePreparationPromptResult.ready(tapSchedule(id));
      };
      ready = true;
      router.routeLocalNotificationTap(tapPayload('A'));
      await gate.run(() async {}, replacesData: true);
      router.routeLocalNotificationTap(tapPayload('A'));
      first.complete(SchedulePreparationPromptResult.ready(tapSchedule('A')));
      await pumpEventQueue();
      expect(count, 2);
      expect(navigation.data, hasLength(1));
      expect(navigation.data.single.isCurrent(), isTrue);
    },
  );

  test(
    'definitive missing or completed is consumed without fallback',
    () async {
      resolve = (id, _) async {
        resolved.add(id);
        return const SchedulePreparationPromptResult.rejected();
      };
      router.routeLocalNotificationTap(tapPayload('A'));
      router.routeLocalNotificationTap(tapPayload('B'));
      ready = true;
      router.retry();
      await pumpEventQueue();
      router.retry();
      await pumpEventQueue();
      expect(resolved, ['B']);
      expect(navigation.extras, isEmpty);
    },
  );

  test(
    'transient DB failure waits for explicit retry, same DB recovery keeps pending',
    () async {
      var unavailable = true;
      resolve = (id, _) async {
        resolved.add(id);
        return unavailable
            ? const SchedulePreparationPromptResult.unavailable()
            : SchedulePreparationPromptResult.ready(tapSchedule(id));
      };
      ready = true;
      router.routeLocalNotificationTap(tapPayload('A'));
      await pumpEventQueue();
      expect(resolved, ['A']);
      expect(navigation.extras, isEmpty);
      ready = false;
      router.retry();
      await pumpEventQueue();
      expect(resolved, ['A']);
      unavailable = false;
      ready = true;
      router.retry();
      await pumpEventQueue();
      expect(navigation.data.single.schedule.id, 'A');
    },
  );

  test(
    'gate reappearing during lookup preserves pending without premature consumption',
    () async {
      final a = Completer<SchedulePreparationPromptResult>();
      resolve = (_, _) => a.future;
      ready = true;
      router.routeLocalNotificationTap(tapPayload('A'));
      ready = false;
      a.complete(SchedulePreparationPromptResult.ready(tapSchedule('A')));
      await pumpEventQueue();
      expect(navigation.extras, isEmpty);
      ready = true;
      router.retry();
      await pumpEventQueue();
      expect(navigation.data, hasLength(1));
    },
  );

  for (final inflight in [false, true]) {
    test(
      'replacement invalidates ${inflight ? 'inflight' : 'pending'} and cold result even with reused ID',
      () async {
        final a = Completer<SchedulePreparationPromptResult>();
        resolve = (_, _) => a.future;
        ready = inflight;
        final initial = router.receipt;
        router.routeLocalNotificationTap(tapPayload('A'));
        await gate.run(() async {}, replacesData: true);
        a.complete(SchedulePreparationPromptResult.ready(tapSchedule('A')));
        router.receiveInitial(tapPayload('A'), initial);
        ready = true;
        router.retry();
        await pumpEventQueue();
        expect(navigation.extras, isEmpty);
        router.routeLocalNotificationTap(tapPayload('A'));
        await pumpEventQueue();
        expect(navigation.data, hasLength(1));
      },
    );
  }
}

class _Navigation extends NavigationService {
  final extras = <Object?>[];
  List<NotificationPromptRouteData> get data =>
      extras.whereType<NotificationPromptRouteData>().toList();
  @override
  void push(String routeName, {Object? extra}) {
    extras.add(extra);
  }
}
