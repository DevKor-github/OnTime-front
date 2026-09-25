// Widget raster evidence for A07 receipts; this does not exercise a mobile OS.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/alarm/screens/alarm_screen.dart';
import 'package:on_time_front/presentation/alarm/screens/schedule_start_screen.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import '../../test/presentation/alarm/screens/preparation_flow_widget_test.dart'
    show StaticScheduleBloc, buildSchedule;

void main() {
  testWidgets('capture preparation start error and recovery at 200 percent', (
    tester,
  ) async {
    final output = Directory(Platform.environment['A07_CAPTURE_DIR']!);
    await tester.runAsync(() => output.create(recursive: true));
    final font = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    await tester.runAsync(font.load);
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 10);
    for (final locale in ['ko', 'en']) {
      for (final partial in [false, true]) {
        final schedule = buildSchedule(
          id: 'capture',
          scheduleTime: now.add(const Duration(hours: 2)),
          steps: [
            PreparationStepWithTimeEntity(
              id: 'one',
              preparationName: locale == 'ko' ? '준비하기' : 'Get ready',
              preparationTime: const Duration(minutes: 10),
              nextPreparationId: 'two',
            ),
            PreparationStepWithTimeEntity(
              id: 'two',
              preparationName: locale == 'ko' ? '다음 단계' : 'Next step',
              preparationTime: const Duration(minutes: 5),
              nextPreparationId: null,
            ),
          ],
        );
        final bloc = _CaptureBloc(
          partial
              ? ScheduleState.started(
                  schedule,
                  isEarlyStarted: true,
                ).copyWith(hasPendingStartRecovery: true)
              : ScheduleState.upcoming(schedule),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          BlocProvider<ScheduleBloc>.value(
            value: bloc,
            child: MaterialApp(
              key: ValueKey('$locale-$partial'),
              theme: themeData,
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(430, 932),
                  textScaler: TextScaler.linear(2),
                ),
                child: RepaintBoundary(
                  key: key,
                  child: partial
                      ? AlarmScreen(nowProvider: () => now)
                      : const ScheduleStartScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!partial) {
          await tester.tap(find.byType(ElevatedButton).first);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('preparation-start-error')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/preparation-${partial ? 'partial' : 'error'}-$locale.png',
          ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
          image.dispose();
        });
        if (partial) {
          final skip = find.text('이 단계 건너 뛰기');
          await tester.scrollUntilVisible(
            skip,
            50,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(skip.hitTestable(), findsOneWidget);
          await tester.tap(skip);
          expect(
            bloc.addedEvents.whereType<ScheduleStepSkipped>(),
            hasLength(1),
          );
          final next = find.text(locale == 'ko' ? '다음 단계' : 'Next step');
          await tester.scrollUntilVisible(
            next,
            50,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(next.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}

class _CaptureBloc extends StaticScheduleBloc {
  _CaptureBloc(super.state);
  @override
  Future<PreparationStartReceipt?> requestPreparationStart({
    required bool Function() isCurrent,
  }) async => throw StateError('simulated durable write failure');
}
