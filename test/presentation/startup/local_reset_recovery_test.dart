import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_lifecycle.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/startup/screens/local_reset_progress_screen.dart';
import 'package:on_time_front/presentation/startup/screens/local_startup_gate.dart';

void main() {
  testWidgets(
    'pre-DI reset failure exposes retry without constructing the normal app',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      var constructed = 0;
      var retried = 0;
      await tester.pumpWidget(
        LocalStartupGate(
          prepare: () async => throw const LocalResetRecoveryRequired(
            LocalResetResult(intentRecorded: true, completed: {}),
          ),
          ready: () {
            constructed++;
            return const Text('normal app');
          },
          retryReset: () async {
            retried++;
            return completed();
          },
        ),
      );
      await tester.pump();
      expect(constructed, 0);
      expect(find.text('Retry cleanup'), findsOneWidget);
      await tester.tap(find.text('Retry cleanup'));
      await tester.pumpAndSettle();
      expect(retried, 1);
      expect(constructed, 0);
      expect(find.text('Local data reset complete'), findsOneWidget);
    },
  );

  testWidgets(
    'pre-DI bootstrap failure can retry without showing private exception text',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      var attempts = 0;
      await tester.pumpWidget(
        LocalStartupGate(
          prepare: () async {
            if (++attempts == 1) throw StateError('PRIVATE PATH');
          },
          ready: () => const MaterialApp(home: Text('ready')),
          retryReset: () async => completed(),
        ),
      );
      await tester.pump();
      expect(find.textContaining('PRIVATE PATH'), findsNothing);
      expect(find.text('ready'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('ready'), findsOneWidget);
    },
  );

  testWidgets(
    'reset invalidation disposes the old app while the actual platform future remains pending',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      final gate = LocalDataOperationGate();
      addTearDown(gate.dispose);
      final latePlatform = Completer<LocalResetResult>();
      var calls = 0;
      var disposals = 0;
      await tester.pumpWidget(
        ResetAwareApp(
          gate: gate,
          reset: () {
            calls++;
            return latePlatform.future;
          },
          child: MaterialApp(home: DisposalProbe(onDispose: () => disposals++)),
        ),
      );
      gate.invalidate();
      await tester.pump();
      expect(disposals, 1);
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 11));
      expect(find.textContaining('Waiting for the device'), findsOneWidget);
      expect(find.text('Retry cleanup'), findsNothing);
      expect(calls, 1);
      latePlatform.complete(completed());
      await tester.pumpAndSettle();
      expect(find.text('Local data reset complete'), findsOneWidget);
      expect(find.text('old app'), findsNothing);
      expect(calls, 1);
    },
  );

  for (final locale in ['ko', 'en']) {
    testWidgets(
      '$locale partial deletion screen is distinct from complete and fits large text',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var retries = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: LocalResetProgressScreen(
              initialResult: const LocalResetResult(
                intentRecorded: true,
                completed: {
                  ResetStep.database,
                  ResetStep.preferences,
                  ResetStep.key,
                  ResetStep.credentials,
                },
              ),
              operation: () async {
                retries++;
                return completed();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(locale == 'ko' ? '일부 알림' : 'some notification'),
          findsOneWidget,
        );
        expect(
          find.text(
            locale == 'ko' ? '로컬 데이터 초기화 완료' : 'Local data reset complete',
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        final button = find.text(locale == 'ko' ? '정리 다시 시도' : 'Retry cleanup');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(retries, 1);
        expect(
          find.text(
            locale == 'ko' ? '로컬 데이터 초기화 완료' : 'Local data reset complete',
          ),
          findsOneWidget,
        );
      },
    );
  }
}

LocalResetResult completed() => LocalResetResult(
  intentRecorded: true,
  completed: ResetStep.values.toSet(),
  isComplete: true,
  recoveryRequired: false,
);

class DisposalProbe extends StatefulWidget {
  const DisposalProbe({super.key, required this.onDispose});
  final VoidCallback onDispose;
  @override
  State<DisposalProbe> createState() => _DisposalProbeState();
}

class _DisposalProbeState extends State<DisposalProbe> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('old app');
}
