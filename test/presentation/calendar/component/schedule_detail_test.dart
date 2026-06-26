import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/calendar/component/schedule_detail.dart';

class _FakeSvgAssetBundle extends CachingAssetBundle {
  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"></svg>';

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(_svg));
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  final schedule = ScheduleEntity(
    id: 'schedule-1',
    place: PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Design Review',
    scheduleTime: DateTime(2026, 3, 20, 9, 0),
    moveTime: const Duration(minutes: 30),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 10),
    scheduleNote: '',
  );

  Future<void> pumpScheduleDetail(
    WidgetTester tester, {
    ScheduleEntity? customSchedule,
    Duration? preparationTime,
    bool isEarlyStarted = false,
  }) async {
    final targetSchedule = customSchedule ?? schedule;
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _FakeSvgAssetBundle(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ScheduleDetail(
              schedule: targetSchedule,
              preparationTime: preparationTime,
              isEarlyStarted: isEarlyStarted,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openTrailingActions(WidgetTester tester) async {
    final cell = find.byType(SwipeActionCell);
    expect(cell, findsOneWidget);
    await tester.drag(cell, const Offset(-180, 0));
    await tester.pumpAndSettle();
  }

  double getMaxActionButtonHeight(WidgetTester tester) {
    final actionContainers = find.byWidgetPredicate((widget) {
      if (widget is! Container) {
        return false;
      }
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) {
        return false;
      }
      final radius = decoration.borderRadius;
      if (radius is! BorderRadius) {
        return false;
      }
      return radius.topLeft.x == 12 && decoration.color != null;
    });

    expect(actionContainers, findsWidgets);
    return actionContainers
        .evaluate()
        .map((element) => (element.renderObject! as RenderBox).size.height)
        .reduce((a, b) => a > b ? a : b);
  }

  int getActionButtonCount(WidgetTester tester) {
    final actionContainers = find.byWidgetPredicate((widget) {
      if (widget is! Container) {
        return false;
      }
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) {
        return false;
      }
      final radius = decoration.borderRadius;
      if (radius is! BorderRadius) {
        return false;
      }
      return radius.topLeft.x == 12 && decoration.color != null;
    });

    return actionContainers.evaluate().length;
  }

  testWidgets('expanded tile shows travel, preparation, spare in order', (
    tester,
  ) async {
    await pumpScheduleDetail(
      tester,
      preparationTime: const Duration(minutes: 20),
    );

    await tester.tap(find.text('Design Review'));
    await tester.pumpAndSettle();

    final travel = find.text('Travel Time');
    final preparation = find.text('Preparation Time');
    final spare = find.text('Spare Time');

    expect(travel, findsOneWidget);
    expect(preparation, findsOneWidget);
    expect(spare, findsOneWidget);
    expect(find.text('20 minutes'), findsOneWidget);

    final travelY = tester.getTopLeft(travel).dy;
    final preparationY = tester.getTopLeft(preparation).dy;
    final spareY = tester.getTopLeft(spare).dy;
    expect(travelY, lessThan(preparationY));
    expect(preparationY, lessThan(spareY));
  });

  testWidgets('preparation fallback is shown as dash when unavailable', (
    tester,
  ) async {
    await pumpScheduleDetail(tester);

    await tester.tap(find.text('Design Review'));
    await tester.pumpAndSettle();

    expect(find.text('Preparation Time'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets(
    'swipe action button height increases when schedule is expanded',
    (tester) async {
      await pumpScheduleDetail(
        tester,
        preparationTime: const Duration(minutes: 20),
      );
      await openTrailingActions(tester);
      final collapsedHeight = getMaxActionButtonHeight(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await pumpScheduleDetail(
        tester,
        preparationTime: const Duration(minutes: 20),
      );
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text('Travel Time'), findsOneWidget);
      await openTrailingActions(tester);
      final expandedHeight = getMaxActionButtonHeight(tester);

      expect(expandedHeight, greaterThan(collapsedHeight));
    },
  );

  testWidgets('tile text updates when schedule fields change for same id', (
    tester,
  ) async {
    await pumpScheduleDetail(tester);

    expect(find.text('Design Review'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);

    final updatedSchedule = ScheduleEntity(
      id: 'schedule-1',
      place: PlaceEntity(id: 'place-1', placeName: 'New Office'),
      scheduleName: 'Edited Review',
      scheduleTime: DateTime(2026, 3, 20, 10, 30),
      moveTime: const Duration(minutes: 45),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 20),
      scheduleNote: '',
    );

    await pumpScheduleDetail(tester, customSchedule: updatedSchedule);

    expect(find.text('Edited Review'), findsOneWidget);
    expect(find.text('New Office'), findsOneWidget);
    expect(find.text('10:30'), findsOneWidget);
    expect(find.text('Design Review'), findsNothing);
    expect(find.text('Office'), findsNothing);
    expect(find.text('09:00'), findsNothing);
  });

  testWidgets('edit action is available before preparation starts', (
    tester,
  ) async {
    final futureSchedule = ScheduleEntity(
      id: 'schedule-2',
      place: PlaceEntity(id: 'place-1', placeName: 'Office'),
      scheduleName: 'Planning',
      scheduleTime: DateTime.now().add(const Duration(hours: 3)),
      moveTime: const Duration(minutes: 30),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 10),
      scheduleNote: '',
    );

    await pumpScheduleDetail(
      tester,
      customSchedule: futureSchedule,
      preparationTime: const Duration(minutes: 20),
    );

    await openTrailingActions(tester);

    expect(getActionButtonCount(tester), 2);
  });

  testWidgets('edit action is hidden after preparation start time', (
    tester,
  ) async {
    final scheduleInPreparation = ScheduleEntity(
      id: 'schedule-3',
      place: PlaceEntity(id: 'place-1', placeName: 'Office'),
      scheduleName: 'Planning',
      scheduleTime: DateTime.now().add(const Duration(minutes: 30)),
      moveTime: const Duration(minutes: 30),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 10),
      scheduleNote: '',
    );

    await pumpScheduleDetail(
      tester,
      customSchedule: scheduleInPreparation,
      preparationTime: const Duration(minutes: 20),
    );

    await openTrailingActions(tester);

    expect(getActionButtonCount(tester), 1);
  });

  testWidgets('edit action is hidden for early-started schedule', (
    tester,
  ) async {
    final futureSchedule = ScheduleEntity(
      id: 'schedule-4',
      place: PlaceEntity(id: 'place-1', placeName: 'Office'),
      scheduleName: 'Planning',
      scheduleTime: DateTime.now().add(const Duration(hours: 3)),
      moveTime: const Duration(minutes: 30),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 10),
      scheduleNote: '',
    );

    await pumpScheduleDetail(
      tester,
      customSchedule: futureSchedule,
      preparationTime: const Duration(minutes: 20),
      isEarlyStarted: true,
    );

    await openTrailingActions(tester);

    expect(getActionButtonCount(tester), 1);
  });

  testWidgets('delete action stays available for started unfinished schedule', (
    tester,
  ) async {
    final startedSchedule = ScheduleEntity(
      id: 'schedule-5',
      place: PlaceEntity(id: 'place-1', placeName: 'Office'),
      scheduleName: 'Planning',
      scheduleTime: DateTime.now().add(const Duration(hours: 3)),
      moveTime: const Duration(minutes: 30),
      isChanged: false,
      isStarted: true,
      scheduleSpareTime: const Duration(minutes: 10),
      scheduleNote: '',
      doneStatus: ScheduleDoneStatus.notEnded,
      startedAt: DateTime.now(),
    );

    await pumpScheduleDetail(
      tester,
      customSchedule: startedSchedule,
      preparationTime: const Duration(minutes: 20),
    );

    await openTrailingActions(tester);

    expect(getActionButtonCount(tester), 1);
  });

  testWidgets('delete action is hidden for finished schedules', (tester) async {
    final finishedSchedule = ScheduleEntity(
      id: 'schedule-6',
      place: PlaceEntity(id: 'place-1', placeName: 'Office'),
      scheduleName: 'Planning',
      scheduleTime: DateTime.now().add(const Duration(hours: 3)),
      moveTime: const Duration(minutes: 30),
      isChanged: false,
      isStarted: true,
      scheduleSpareTime: const Duration(minutes: 10),
      scheduleNote: '',
      doneStatus: ScheduleDoneStatus.normalEnd,
      startedAt: DateTime.now().subtract(const Duration(hours: 1)),
      finishedAt: DateTime.now(),
    );

    await pumpScheduleDetail(
      tester,
      customSchedule: finishedSchedule,
      preparationTime: const Duration(minutes: 20),
    );

    await openTrailingActions(tester);

    expect(getActionButtonCount(tester), 0);
  });
}
