import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/domain/entities/local_reset_result.dart';
import 'package:on_time_front/presentation/startup/screens/local_startup_gate.dart';

void main() {
  testWidgets('damaged store offers backup recovery before normal DI', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      LocalStartupGate(
        recovery: () async => throw StateError('Not selected yet'),
        prepare: () async => throw const RestoreStoreUnavailable('private'),
        ready: () => throw StateError('No product graph before recovery'),
        retryReset: () async =>
            const LocalResetResult(intentRecorded: false, completed: {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restore an OnTime Backup'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
  });
}
