import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';

void main() {
  testWidgets('minute picker saves the selected duration and disposes', (
    tester,
  ) async {
    Duration? saved;
    var disposedCount = 0;

    await tester.pumpWidget(
      _TestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => context.showCupertinoMinutePickerModal(
              title: 'Preparation minutes',
              initialValue: const Duration(minutes: 7),
              onSaved: (value) => saved = value,
              onDisposed: () => disposedCount += 1,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Preparation minutes'), findsOneWidget);
    expect(find.text('07'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(saved, const Duration(minutes: 7));
    expect(disposedCount, 1);
    expect(find.text('Preparation minutes'), findsNothing);
  });

  testWidgets('minute picker cancel disposes without saving', (tester) async {
    Duration? saved;
    var disposedCount = 0;

    await tester.pumpWidget(
      _TestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => context.showCupertinoMinutePickerModal(
              title: 'Preparation minutes',
              initialValue: const Duration(minutes: 3),
              onSaved: (value) => saved = value,
              onDisposed: () => disposedCount += 1,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(saved, isNull);
    expect(disposedCount, 1);
  });

  testWidgets('timer picker saves the initial timer duration', (tester) async {
    Duration? saved;

    await tester.pumpWidget(
      _TestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => context.showCupertinoTimerPickerModal(
              title: 'Move time',
              initialValue: const Duration(minutes: 20),
              mode: CupertinoTimerPickerMode.hm,
              onSaved: (value) => saved = value,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(saved, const Duration(minutes: 20));
  });

  testWidgets('date picker saves the initial date value', (tester) async {
    DateTime? saved;
    final initial = DateTime(2026, 5, 15, 9, 30);

    await tester.pumpWidget(
      _TestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => context.showCupertinoDatePickerModal(
              title: 'Schedule date',
              initialValue: initial,
              mode: CupertinoDatePickerMode.dateAndTime,
              onSaved: (value) => saved = value,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(saved, initial);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );
  }
}
