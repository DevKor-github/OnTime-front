import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_graph_animator.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_graph_component.dart';
import 'package:on_time_front/presentation/alarm/screens/alarm_screen.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

import '../../../helpers/visual_test_fonts.dart';

class _StaticScheduleBloc implements ScheduleBloc {
  _StaticScheduleBloc(this.state);
  @override
  final ScheduleState state;
  final events = <ScheduleEvent>[];
  @override
  Stream<ScheduleState> get stream => const Stream.empty();
  @override
  void add(ScheduleEvent event) => events.add(event);
  @override
  bool get isClosed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _now = DateTime(2024, 12, 21, 10);

ScheduleWithPreparationEntity _schedule({bool late = false}) =>
    ScheduleWithPreparationEntity(
      id: 'runtime-visual',
      scheduleName: '친구와 약속',
      place: PlaceEntity(id: 'place', placeName: '강남역'),
      scheduleTime: _now.add(Duration(minutes: late ? 10 : 90)),
      moveTime: const Duration(minutes: 20),
      scheduleSpareTime: Duration.zero,
      isChanged: false,
      isStarted: true,
      scheduleNote: '',
      preparation: PreparationWithTimeEntity(
        preparationStepList: [
          PreparationStepWithTimeEntity(
            id: '1',
            preparationName: '샤워하기',
            preparationTime: const Duration(minutes: 10),
            elapsedTime: const Duration(minutes: 9, seconds: 50),
            nextPreparationId: '2',
          ),
          PreparationStepWithTimeEntity(
            id: '2',
            preparationName: '메이크업',
            preparationTime: const Duration(minutes: 20),
            nextPreparationId: '3',
          ),
          PreparationStepWithTimeEntity(
            id: '3',
            preparationName: '옷 고르기/입기',
            preparationTime: const Duration(minutes: 20),
            nextPreparationId: '4',
          ),
          PreparationStepWithTimeEntity(
            id: '4',
            preparationName: '헤어',
            preparationTime: const Duration(minutes: 20),
            nextPreparationId: null,
          ),
        ],
      ),
    );

Future<_StaticScheduleBloc> _pump(
  WidgetTester tester, {
  bool late = false,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final bloc = _StaticScheduleBloc(
    ScheduleState.started(_schedule(late: late)),
  );
  await tester.pumpWidget(
    BlocProvider<ScheduleBloc>.value(
      value: bloc,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themeData,
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 44),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: AlarmScreen(nowProvider: () => _now),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

void main() {
  setUpAll(loadVisualTestFonts);

  for (final late in [false, true]) {
    testWidgets(
      'runtime ${late ? 'late' : 'on time'} matches its visual reference',
      (tester) async {
        await _pump(tester, late: late);
        expect(tester.takeException(), isNull);
        expect(find.text('0:10'), findsOneWidget);
        expect(find.text('0분 10초'), findsOneWidget);
        expect(
          tester.getSize(find.byType(AlarmGraphAnimator)),
          const Size.square(268),
        );
        expect(
          tester.getTopLeft(find.byType(AlarmGraphAnimator)).dy,
          closeTo(121, 2),
        );
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            '../../../goldens/goldens/runtime_${late ? 'late' : 'on_time'}_390x844.png',
          ),
        );
      },
    );
  }

  testWidgets(
    'manual finish can be cancelled and persists only after confirmation',
    (tester) async {
      final bloc = await _pump(tester);
      await tester.tap(find.text('준비 종료'));
      await tester.pumpAndSettle();
      expect(find.text('준비가 모두 끝나셨나요?'), findsOneWidget);
      expect(bloc.events.whereType<ScheduleFinished>(), isEmpty);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../../goldens/goldens/runtime_finish_confirm_390x844.png',
        ),
      );
      await tester.tap(find.text('계속 준비'));
      await tester.pumpAndSettle();
      expect(find.byType(TwoActionDialog), findsNothing);
      expect(bloc.events.whereType<ScheduleFinished>(), isEmpty);
      await tester.tap(find.text('준비 종료'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(TwoActionDialog),
          matching: find.text('준비 종료'),
        ),
      );
      await tester.pumpAndSettle();
      expect(bloc.events.whereType<ScheduleFinished>(), hasLength(1));
    },
  );

  testWidgets('runtime keeps skip and finish reachable with enlarged text', (
    tester,
  ) async {
    final bloc = await _pump(tester, size: const Size(320, 640), scale: 2);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('이 단계 건너 뛰기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 단계 건너 뛰기'));
    await tester.pump();
    expect(bloc.events.whereType<ScheduleStepSkipped>(), hasLength(1));
    expect(find.text('준비 종료').hitTestable(), findsOneWidget);
  });

  testWidgets('timer ring immediately restores saved progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AlarmGraphAnimator(
            progress: .7,
            backgroundColor: Colors.blue,
            progressColor: Colors.white,
          ),
        ),
      ),
    );
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(AlarmGraphAnimator),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((paint.painter! as AlarmGraphComponent).progress, .7);
  });
}
