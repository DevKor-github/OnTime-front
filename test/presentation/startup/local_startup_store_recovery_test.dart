import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/core/database/bootstrap_privacy_boundary.dart';
import 'package:on_time_front/core/startup/startup_failure.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/startup/startup_dependency_scope.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import 'package:on_time_front/data/adapters/local_data_workflow_adapters.dart';
import '../../core/database/local_reset_protocol_test.dart' as reset_fixtures;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/domain/entities/local_reset_result.dart';
import 'package:on_time_front/presentation/startup/screens/local_startup_gate.dart';

void main() {
  setUpAll(() async {
    if (Platform.environment['ONTIME_D01_CAPTURE_DIR'] != null) {
      final font = FontLoader('Pretendard')
        ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
      await font.load();
    }
  });
  testWidgets(
    'unreadable pre-DI store keeps explicit reset reachable without DI',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      await tester.pumpWidget(
        LocalStartupGate(
          prepare: () async =>
              throw const RestoreStoreUnavailable('PRIVATE-KEY-PATH'),
          ready: () => throw StateError('Normal app must not be constructed'),
          beginReset: () async =>
              const LocalResetResult(intentRecorded: true, completed: {}),
          retryReset: () async =>
              const LocalResetResult(intentRecorded: false, completed: {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE-KEY-PATH'), findsNothing);
      expect(find.text('Reset all local data'), findsOneWidget);
    },
  );
  for (final preserved in [true, false]) {
    testWidgets(
      'bootstrap and privacy double failure preserves classified reset access: $preserved',
      (tester) async {
        tester.binding.platformDispatcher.localesTestValue = const [
          Locale('en'),
        ];
        addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
        var bootstrapCalls = 0;
        var cleanupCalls = 0;
        await tester.pumpWidget(
          LocalStartupGate(
            prepare: () => startupStage(
              StartupStage.lifecycle,
              () => bootstrapWithPrivacyCleanup(
                bootstrap: () async {
                  bootstrapCalls++;
                  if (preserved) throw const LocalStorePreservationRequired();
                  throw StateError('PRIVATE-BOOTSTRAP');
                },
                cleanup: () async {
                  cleanupCalls++;
                  throw StateError('PRIVATE-CLEANUP');
                },
              ),
            ),
            ready: () => throw StateError('No normal app'),
            beginReset: () => throw StateError('No implicit reset'),
            retryReset: () => throw StateError('No invented intent'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Reset all local data'),
          preserved ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(
            'Privacy cleanup of previous temporary information is also incomplete.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('PRIVATE'), findsNothing);
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(bootstrapCalls, 2);
        expect(cleanupCalls, 2);
      },
    );
  }
  for (final ko in [false, true]) {
    testWidgets(
      '${ko ? 'ko' : 'en'} pre-DI cancel preserves intent; confirmation reaches actual reset protocol',
      (tester) async {
        tester.binding.platformDispatcher.localeTestValue = Locale(
          ko ? 'ko' : 'en',
        );
        addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
        tester.binding.platformDispatcher.localesTestValue = [
          Locale(ko ? 'ko' : 'en'),
        ];
        addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final actions = reset_fixtures.FakeActions();
        final rig = reset_fixtures.Rig(
          AlarmOwnershipJournal(MemoryAlarmJournalStore()),
          actions,
        );
        addTearDown(rig.owner.dispose);
        final workflow = LocalResetWorkflow(
          RecoveryResetAdapter(() => rig.run(begin: true)),
        );
        final screenshotKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenshotKey,
            child: LocalStartupGate(
              prepare: () async =>
                  throw const RestoreStoreUnavailable('PRIVATE'),
              ready: () => throw StateError('DI forbidden'),
              beginReset: workflow.call,
              retryReset: () => rig.run(begin: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          Localizations.localeOf(
            tester.element(find.byType(Scaffold)),
          ).languageCode,
          ko ? 'ko' : 'en',
        );
        await _capture(
          tester,
          screenshotKey,
          '${ko ? 'ko' : 'en'}-preservation',
        );
        final reset = find.text(ko ? '로컬 데이터 초기화' : 'Reset all local data');
        await tester.ensureVisible(reset);
        await tester.tap(reset);
        await tester.pumpAndSettle();
        await _capture(tester, screenshotKey, '${ko ? 'ko' : 'en'}-confirm');
        await tester.tap(find.text(ko ? '취소' : 'Cancel'));
        await tester.pumpAndSettle();
        expect(actions.performed, isEmpty);
        expect(actions.marker, false);
        expect((await rig.journal.read()).reset, ResetPhase.none);
        await tester.tap(reset);
        await tester.pumpAndSettle();
        await tester.tap(find.text(ko ? '모두 삭제' : 'Delete all'));
        await tester.pumpAndSettle();
        expect(actions.performed.toSet(), ResetStep.values.toSet());
        expect(
          find.text(ko ? '로컬 데이터 초기화 완료' : 'Local data reset complete'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final ko in [false, true]) {
    for (final pending in [false, true]) {
      testWidgets(
        '${ko ? 'ko' : 'en'} ${pending ? 'waiting' : 'restore cleanup'} stays accessible at 200 percent',
        (tester) async {
          tester.binding.platformDispatcher.localesTestValue = [
            Locale(ko ? 'ko' : 'en'),
          ];
          addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final key = GlobalKey();
          final completion = Completer<void>();
          final phase = ValueNotifier(StartupStage.store);
          addTearDown(phase.dispose);
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: LocalStartupGate(
                stage: phase,
                prepare: () => pending
                    ? completion.future
                    : Future.error(const RestoreRecoveryRequired('PRIVATE')),
                ready: () => const MaterialApp(home: Text('ready')),
                beginReset: () => throw StateError('new reset forbidden'),
                retryReset: () => throw StateError('reset resume forbidden'),
              ),
            ),
          );
          if (pending) {
            await tester.pump(const Duration(seconds: 10));
            await tester.pump();
          } else {
            await tester.pumpAndSettle();
          }
          expect(
            find.text(ko ? '암호화된 로컬 데이터 확인' : 'Checking encrypted local data'),
            findsOneWidget,
          );
          expect(
            find.text(ko ? '로컬 데이터 초기화' : 'Reset all local data'),
            findsNothing,
          );
          expect(
            find.text(ko ? '다시 시도' : 'Try again'),
            pending ? findsNothing : findsOneWidget,
          );
          expect(find.textContaining('PRIVATE'), findsNothing);
          await _capture(
            tester,
            key,
            '${ko ? 'ko' : 'en'}-${pending ? 'waiting' : 'restore-cleanup'}',
          );
          expect(tester.takeException(), isNull);
          if (pending) {
            completion.complete();
            await tester.pumpAndSettle();
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'known restore cleanup exposes retry only, never new reset or a second import',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      var retries = 0;
      await tester.pumpWidget(
        LocalStartupGate(
          prepare: () async {
            retries++;
            throw const RestoreRecoveryRequired('PRIVATE');
          },
          ready: () => throw StateError('DI forbidden'),
          beginReset: () => throw StateError('New reset forbidden'),
          retryReset: () => throw StateError('Reset resume forbidden'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Restored data has pending cleanup.'), findsOneWidget);
      expect(find.text('Reset all local data'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(retries, 2);
    },
  );

  testWidgets(
    'failed cleanup blocks new graph and retry cleans the same attempt first',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      var prepares = 0;
      var graphs = 0;
      var cleanupCalls = 0;
      var failCleanup = true;
      await tester.pumpWidget(
        LocalStartupGate(
          prepare: () async {
            prepares++;
          },
          ready: () {
            if (++graphs == 1) throw StateError('partial graph');
            return const MaterialApp(home: Text('ready'));
          },
          cleanupAttempt: () async {
            cleanupCalls++;
            if (failCleanup) throw const StartupCleanupIncomplete();
          },
          retryReset: () => throw StateError('reset forbidden'),
        ),
      );
      await tester.pumpAndSettle();
      expect(prepares, 1);
      expect(graphs, 1);
      expect(cleanupCalls, 1);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(prepares, 1);
      expect(graphs, 1);
      expect(cleanupCalls, 2);
      failCleanup = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(cleanupCalls, 3);
      expect(prepares, 2);
      expect(graphs, 2);
      expect(find.text('ready'), findsOneWidget);
    },
  );

  testWidgets(
    'waiting threshold does not create retry or dispose the pending owner',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        LocalStartupGate(
          prepare: () {
            calls++;
            return pending.future;
          },
          ready: () => const MaterialApp(home: Text('ready')),
          retryReset: () => throw StateError('reset forbidden'),
        ),
      );
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Startup is still in progress.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('ready'), findsOneWidget);
    },
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['ONTIME_D01_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
