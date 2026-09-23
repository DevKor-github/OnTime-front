import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

import '../../../helpers/visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualTestFonts);

  Future<void> pumpTile(
    WidgetTester tester, {
    ScheduleEntity? schedule,
    TodayScheduleTileState state = TodayScheduleTileState.scheduled,
    VoidCallback? onTap,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(318, 54);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        locale: const Locale('ko'),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TodaysScheduleTile(
            schedule: schedule,
            state: state,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  testWidgets('scheduled status matches the Figma component', (tester) async {
    var tapCount = 0;
    await pumpTile(tester, schedule: _schedule(), onTap: () => tapCount++);

    expect(find.text('5월 12일 오후 6시'), findsOneWidget);
    expect(find.text('OO과 데이트'), findsOneWidget);
    expect(
      tester.getSize(find.byType(TodaysScheduleTile)),
      const Size(318, 54),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        '../../../goldens/goldens/today_status_scheduled_318x54.png',
      ),
    );
    await tester.tap(find.byType(TodaysScheduleTile));
    expect(tapCount, 1);
  });

  testWidgets('active and completed statuses keep their distinct labels', (
    tester,
  ) async {
    await pumpTile(
      tester,
      schedule: _schedule(),
      state: TodayScheduleTileState.active,
    );
    expect(find.text('준비 진행 중'), findsOneWidget);
    expect(find.text('OO과 데이트'), findsOneWidget);

    await pumpTile(
      tester,
      schedule: _schedule(),
      state: TodayScheduleTileState.completed,
    );
    expect(find.text('완료'), findsOneWidget);
    expect(find.text('OO과 데이트'), findsOneWidget);
  });

  testWidgets('empty status retains the source message', (tester) async {
    await pumpTile(tester);
    expect(find.text('약속이 없는 날이에요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ScheduleEntity _schedule() => ScheduleEntity(
  id: 'figma-today',
  place: const PlaceEntity(id: 'place-1', placeName: '카페'),
  scheduleName: 'OO과 데이트',
  scheduleTime: DateTime(2024, 5, 12, 18),
  moveTime: const Duration(minutes: 20),
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: const Duration(minutes: 10),
  scheduleNote: '',
);
