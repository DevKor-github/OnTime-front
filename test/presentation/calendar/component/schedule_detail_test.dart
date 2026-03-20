import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    Duration? preparationTime,
  }) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _FakeSvgAssetBundle(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ScheduleDetail(
              schedule: schedule,
              preparationTime: preparationTime,
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

  testWidgets('expanded tile shows travel, preparation, spare in order',
      (tester) async {
    await pumpScheduleDetail(tester,
        preparationTime: const Duration(minutes: 20));

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

  testWidgets('preparation fallback is shown as dash when unavailable',
      (tester) async {
    await pumpScheduleDetail(tester);

    await tester.tap(find.text('Design Review'));
    await tester.pumpAndSettle();

    expect(find.text('Preparation Time'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('swipe action button height increases when schedule is expanded',
      (tester) async {
    await pumpScheduleDetail(tester,
        preparationTime: const Duration(minutes: 20));
    await openTrailingActions(tester);
    final collapsedHeight = getMaxActionButtonHeight(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpScheduleDetail(tester,
        preparationTime: const Duration(minutes: 20));
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('Travel Time'), findsOneWidget);
    await openTrailingActions(tester);
    final expandedHeight = getMaxActionButtonHeight(tester);

    expect(expandedHeight, greaterThan(collapsedHeight));
  });
}
