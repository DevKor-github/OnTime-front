import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/time/device_time_zone_scope.dart';
import 'package:on_time_front/presentation/shared/time/device_time_zone_state.dart';

void main() {
  test(
    'late successful and failed reads cannot replace the latest zone',
    () async {
      final replies = <Completer<String>>[];
      final controller = DeviceTimeZoneController(
        readZone: () {
          final response = Completer<String>();
          replies.add(response);
          return response.future;
        },
      );
      addTearDown(controller.dispose);
      final old = controller.refresh();
      final latest = controller.refresh();
      replies[1].complete('Asia/Tokyo');
      await latest;
      replies[0].complete('Asia/Seoul');
      await old;
      expect(controller.value, const DeviceTimeZoneState.known('Asia/Tokyo'));
      final failed = controller.refresh();
      final newest = controller.refresh();
      replies[3].complete('America/New_York');
      await newest;
      replies[2].completeError(StateError('old plugin failure'));
      await failed;
      expect(
        controller.value,
        const DeviceTimeZoneState.known('America/New_York'),
      );
    },
  );

  test(
    'unavailable and disposal do not fabricate UTC or accept an old read',
    () async {
      final response = Completer<String>();
      final controller = DeviceTimeZoneController(
        readZone: () => response.future,
      );
      final pending = controller.refresh();
      controller.dispose();
      response.complete('Asia/Seoul');
      await pending;
      final invalid = DeviceTimeZoneController(
        readZone: () async => 'Missing/Zone',
      );
      addTearDown(invalid.dispose);
      await invalid.refresh();
      expect(invalid.value, const DeviceTimeZoneState.unavailable());
    },
  );

  testWidgets('paused mount and controller replacement do not start polling', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    var firstReads = 0, secondReads = 0;
    final first = DeviceTimeZoneController(
      readZone: () async {
        firstReads++;
        return 'Asia/Seoul';
      },
    );
    final second = DeviceTimeZoneController(
      readZone: () async {
        secondReads++;
        return 'Asia/Tokyo';
      },
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget host(DeviceTimeZoneController controller) =>
        DeviceTimeZoneScope(controller: controller, child: const SizedBox());
    await tester.pumpWidget(host(first));
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpWidget(host(second));
    await tester.pump(const Duration(minutes: 2));
    expect(firstReads, 0);
    expect(secondReads, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(secondReads, 1);
    await tester.pump(const Duration(minutes: 1));
    expect(secondReads, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'pause resume and replacing scope ignore earlier plugin completion',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final replies = <Completer<String>>[];
      final first = DeviceTimeZoneController(
        readZone: () {
          final reply = Completer<String>();
          replies.add(reply);
          return reply.future;
        },
      );
      final second = DeviceTimeZoneController(
        readZone: () async => 'Asia/Tokyo',
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget host(DeviceTimeZoneController controller) => DeviceTimeZoneScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Text(
              DeviceTimeZoneScope.stateOf(context).identifier ?? 'unavailable',
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(first));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      replies[1].complete('America/New_York');
      await tester.pump();
      expect(find.text('America/New_York'), findsOneWidget);
      await tester.pumpWidget(host(second));
      await tester.pump();
      replies[0].complete('Asia/Seoul');
      await tester.pump();
      expect(find.text('Asia/Tokyo'), findsOneWidget);
      expect(first.value, const DeviceTimeZoneState.known('America/New_York'));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
