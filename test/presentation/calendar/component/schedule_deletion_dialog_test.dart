import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/calendar/component/schedule_deletion_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/presentation/shared/time/device_time_zone_scope.dart';
import '../../../helpers/refresh_capture.dart';

// Presentation evidence only. DB, backup and file-journal proofs are separate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRefreshFonts);

  Future<AppLocalizations> open(
    WidgetTester tester,
    _ScriptedDeletion service, {
    String language = 'en',
    double scale = 1,
    List<bool>? results,
    RecurringEditScope? scope,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final zone = DeviceTimeZoneController(readZone: () async => 'UTC');
    addTearDown(zone.dispose);
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: DeviceTimeZoneScope(controller: zone, child: child!),
        ),
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final deleted = await showScheduleDeletionDialog(
                      context,
                      schedule: service.intent.snapshot.schedule,
                      deletions: service,
                      scope: scope,
                    );
                    results?.add(deleted);
                  },
                  child: const Text('Open history deletion'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open history deletion'));
    await _paint(tester);
    return l10n;
  }

  for (final language in ['ko', 'en']) {
    testWidgets(
      '$language following confirmation describes edited future occurrences accurately',
      (tester) async {
        final service = _ScriptedDeletion();
        final future = _history.copyWith(
          scheduleTime: DateTime.utc(2035, 1, 1, 9),
          doneStatus: ScheduleDoneStatus.notEnded,
          recurringSegmentId: 'series-segment',
          recurringSlotKey: '2035-01-01T09:00',
          recurringOrdinal: 0,
        );
        service.intent = ScheduleDeletionIntent(
          intentId: 'following-confirmation',
          snapshot: ScheduleEditSnapshot(
            future,
            service.intent.snapshot.preparation,
            service.intent.snapshot.baseline,
          ),
          scope: RecurringEditScope.following,
          targets: service.intent.targets,
        );
        final l10n = await open(
          tester,
          service,
          language: language,
          scale: 2,
          scope: RecurringEditScope.following,
        );
        expect(find.text(l10n.scheduleDeletionFollowing), findsOneWidget);
        expect(
          find.text(l10n.scheduleDeletionFollowingConsequences),
          findsOneWidget,
        );
        expect(find.text(l10n.scheduleDeletionConsequences), findsNothing);
        expect(find.text(l10n.scheduleDeletionOnlySelected), findsNothing);
        expect(
          l10n.scheduleDeletionFollowingConsequences,
          contains(language == 'ko' ? '개별' : 'edited'),
        );
        expect(tester.takeException(), isNull);
        _expectScopeVisible(
          tester,
          l10n.scheduleDeletionFollowing,
          l10n.deleteScheduleConfirmAction,
        );
        await captureRefresh(tester, 'u01-$language-following-200');
        await _readConsequencesEnd(
          tester,
          l10n.scheduleDeletionFollowingConsequences,
          l10n.deleteScheduleConfirmAction,
        );
        await captureRefresh(tester, 'u01-$language-following-end-200');
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await _paint(tester);
        expect(service.confirms, 0);
      },
    );

    testWidgets(
      '$language confirmation remains accessible at 200% and cancel writes nothing',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final service = _ScriptedDeletion();
          final returned = <bool>[];
          final l10n = await open(
            tester,
            service,
            language: language,
            scale: 2,
            results: returned,
          );
          expect(find.text(_history.scheduleName), findsOneWidget);
          expect(find.text(l10n.scheduleDeletionOnlySelected), findsOneWidget);
          expect(find.text(l10n.scheduleDeletionConsequences), findsOneWidget);
          expect(
            find.bySemanticsLabel(l10n.deleteScheduleConfirmAction),
            findsOneWidget,
          );
          expect(find.bySemanticsLabel(l10n.cancel), findsOneWidget);
          expect(tester.takeException(), isNull);
          _expectScopeVisible(
            tester,
            l10n.scheduleDeletionOnlySelected,
            l10n.deleteScheduleConfirmAction,
          );
          await captureRefresh(tester, 'u01-$language-confirm-200');
          await _readConsequencesEnd(
            tester,
            l10n.scheduleDeletionConsequences,
            l10n.deleteScheduleConfirmAction,
          );
          await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
          await _paint(tester);
          expect(returned, [false]);
          expect(service.confirms, 0);
          expect(service.retries, 0);
          expect(find.byType(AlertDialog), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      '$language committed partial retains removal and retries only cleanup at 200%',
      (tester) async {
        final service = _ScriptedDeletion()
          ..nextCleanup = ScheduleDeletionCleanup.pending;
        final l10n = await open(tester, service, language: language, scale: 2);
        await tester.tap(
          find.widgetWithText(TextButton, l10n.deleteScheduleConfirmAction),
        );
        await _paint(tester);
        expect(find.text(l10n.scheduleDeletionRemovedTitle), findsOneWidget);
        expect(find.text(l10n.scheduleDeletionPending), findsOneWidget);
        expect(find.text(l10n.scheduleDeleteFailedTitle), findsNothing);
        expect(find.text(l10n.scheduleDeletionComplete), findsNothing);
        expect(tester.takeException(), isNull);
        await captureRefresh(tester, 'u01-$language-partial-200');
        service.nextCleanup = ScheduleDeletionCleanup.complete;
        await tester.tap(
          find.widgetWithText(TextButton, l10n.scheduleDeletionRetryCleanup),
        );
        await _paint(tester);
        expect(service.prepares, 1);
        expect(service.confirms, 1);
        expect(service.retries, 1);
        expect(find.text(l10n.scheduleDeletionComplete), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, l10n.ok));
        await _paint(tester);
      },
    );
  }

  for (final status in [
    ScheduleDoneStatus.normalEnd,
    ScheduleDoneStatus.notEnded,
  ]) {
    testWidgets(
      'past recurring $status skips following selection and prepares occurrence only',
      (tester) async {
        final service = _ScriptedDeletion();
        final history = _history.copyWith(
          scheduleTime: DateTime.utc(2001, 1, 1, 9),
          doneStatus: status,
          recurringSegmentId: 'historical-segment',
          recurringSlotKey: '2001-01-01T09:00',
          recurringOrdinal: 0,
        );
        service.intent = ScheduleDeletionIntent(
          intentId: 'past-occurrence',
          snapshot: ScheduleEditSnapshot(
            history,
            service.intent.snapshot.preparation,
            service.intent.snapshot.baseline,
          ),
          scope: RecurringEditScope.occurrence,
          targets: service.intent.targets,
        );
        final l10n = await open(tester, service);
        expect(service.prepares, 1);
        expect(service.lastScope, RecurringEditScope.occurrence);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(l10n.scheduleDeletionOnlySelected), findsOneWidget);
        expect(find.text(l10n.scheduleDeletionFollowing), findsNothing);
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await _paint(tester);
        expect(service.confirms, 0);
      },
    );
  }

  testWidgets(
    'barrier tap preserves confirmation and system back cancels without mutation',
    (tester) async {
      final service = _ScriptedDeletion();
      final returned = <bool>[];
      await open(tester, service, results: returned);
      await tester.tapAt(const Offset(4, 4));
      await _paint(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(returned, isEmpty);
      expect(service.confirms, 0);
      await tester.binding.handlePopRoute();
      await _paint(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(returned, [false]);
      expect(service.confirms, 0);
      expect(service.retries, 0);
    },
  );

  testWidgets(
    'DB failure never shows removed or cleanup retry and hides raw exception content',
    (tester) async {
      final service = _ScriptedDeletion()
        ..confirmFailure = StateError('PRIVATE SQL DETAIL');
      final l10n = await open(tester, service);
      await tester.tap(
        find.widgetWithText(TextButton, l10n.deleteScheduleConfirmAction),
      );
      await _paint(tester);
      expect(find.text(l10n.scheduleDeleteFailedTitle), findsOneWidget);
      expect(find.text(l10n.scheduleDeletionRemovedTitle), findsNothing);
      expect(find.text(l10n.scheduleDeletionRetryCleanup), findsNothing);
      expect(find.textContaining('PRIVATE SQL DETAIL'), findsNothing);
      expect(service.confirms, 1);
      expect(service.retries, 0);
      expect(tester.takeException(), isNull);
      await captureRefresh(tester, 'u01-en-db-failure');
      await tester.tap(find.widgetWithText(TextButton, l10n.ok));
      await _paint(tester);
    },
  );

  testWidgets(
    'protected preparation exposes guidance without a destructive action',
    (tester) async {
      final service = _ScriptedDeletion()
        ..prepareFailure = const ScheduleDeletionRejected(
          ScheduleDeletionFailure.protected,
        );
      final l10n = await open(tester, service);
      expect(find.text(l10n.scheduleDeletionPreparationActive), findsOneWidget);
      expect(find.text(l10n.deleteScheduleConfirmAction), findsNothing);
      expect(service.confirms, 0);
      await tester.tap(find.widgetWithText(TextButton, l10n.ok));
      await _paint(tester);
    },
  );

  testWidgets(
    'already absent receipt does not present a new or historical deletion success',
    (tester) async {
      final service = _ScriptedDeletion()
        ..commit = ScheduleDeletionCommit(
          scheduleId: 'history',
          store: 'store',
          generation: 0,
          removedIds: {},
          changed: false,
          alreadyAbsent: true,
        );
      final l10n = await open(tester, service);
      await tester.tap(
        find.widgetWithText(TextButton, l10n.deleteScheduleConfirmAction),
      );
      await _paint(tester);
      expect(find.text(l10n.scheduleDeletionAbsentTitle), findsOneWidget);
      expect(find.text(l10n.scheduleDeletionAlreadyAbsent), findsOneWidget);
      expect(find.text(l10n.scheduleDeletionRemovedTitle), findsNothing);
      expect(find.text(l10n.scheduleDeletionComplete), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, l10n.ok));
      await _paint(tester);
    },
  );

  testWidgets(
    'cancel during preparation ignores its later result without mutation',
    (tester) async {
      final service = _ScriptedDeletion()
        ..preparation = Completer<ScheduleDeletionIntent>();
      final returned = <bool>[];
      final l10n = await open(tester, service, results: returned);
      try {
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await _paint(tester);
        service.preparation!.complete(service.intent);
        await _paint(tester);
        expect(returned, [false]);
        expect(service.confirms, 0);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        if (!service.preparation!.isCompleted) {
          service.preparation!.complete(service.intent);
        }
      }
    },
  );

  testWidgets(
    'committed delayed cleanup can close without duplicate work or false completion',
    (tester) async {
      final service = _ScriptedDeletion()
        ..completion = Completer<ScheduleDeletionResult>();
      final returned = <bool>[];
      final l10n = await open(tester, service, results: returned);
      try {
        await tester.tap(
          find.widgetWithText(TextButton, l10n.deleteScheduleConfirmAction),
        );
        await _paint(tester);
        service.commitObserver!(service.commit);
        await _paint(tester);
        expect(find.text(l10n.scheduleDeletionCleaning), findsOneWidget);
        final retry = tester.widget<TextButton>(
          find.widgetWithText(TextButton, l10n.scheduleDeletionRetryCleanup),
        );
        expect(retry.onPressed, isNull);
        await tester.pump(const Duration(seconds: 10));
        expect(find.text(l10n.scheduleDeletionPending), findsOneWidget);
        expect(find.text(l10n.scheduleDeletionComplete), findsNothing);
        await tester.tap(find.widgetWithText(TextButton, l10n.ok));
        await _paint(tester);
        expect(returned, [true]);
        expect(find.byType(AlertDialog), findsNothing);
        expect(service.completion!.isCompleted, isFalse);
        expect(service.confirms, 1);
        expect(service.retries, 0);
        service.completion!.complete(service.result);
        await _paint(tester);
        expect(tester.takeException(), isNull);
      } finally {
        if (!service.completion!.isCompleted) {
          service.completion!.complete(service.result);
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('replacement generation rejects an old commit projection', (
    tester,
  ) async {
    final service = _ScriptedDeletion()
      ..completion = Completer<ScheduleDeletionResult>();
    final l10n = await open(tester, service);
    try {
      await tester.tap(
        find.widgetWithText(TextButton, l10n.deleteScheduleConfirmAction),
      );
      await _paint(tester);
      service.generation++;
      service.commitObserver!(service.commit);
      service.completion!.complete(service.result);
      await _paint(tester);
      expect(find.text(l10n.scheduleDeletionRemovedTitle), findsNothing);
      expect(find.text(l10n.scheduleDeletionComplete), findsNothing);
      expect(service.confirms, 1);
      expect(tester.takeException(), isNull);
    } finally {
      if (!service.completion!.isCompleted) {
        service.completion!.complete(service.result);
      }
      // Production replacement removes the old route; explicitly unmount it here.
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('late preparation from replaced data cannot enable deletion', (
    tester,
  ) async {
    final service = _ScriptedDeletion()
      ..preparation = Completer<ScheduleDeletionIntent>();
    final l10n = await open(tester, service);
    try {
      service.generation++;
      service.preparation!.complete(service.intent);
      await _paint(tester);
      expect(find.text(l10n.deleteScheduleConfirmAction), findsNothing);
      expect(find.text(_history.scheduleName), findsNothing);
      expect(service.confirms, 0);
      expect(tester.takeException(), isNull);
    } finally {
      if (!service.preparation!.isCompleted) {
        service.preparation!.complete(service.intent);
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Future<void> _paint(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void _expectScopeVisible(
  WidgetTester tester,
  String scope,
  String deleteLabel,
) {
  final area = tester.getRect(find.byType(AlertDialog));
  final scopeRect = tester.getRect(find.text(scope));
  final action = tester.getRect(find.widgetWithText(TextButton, deleteLabel));
  expect(scopeRect.top, greaterThanOrEqualTo(area.top));
  expect(scopeRect.bottom, lessThanOrEqualTo(action.top));
}

Future<void> _readConsequencesEnd(
  WidgetTester tester,
  String text,
  String deleteLabel,
) async {
  await Scrollable.ensureVisible(tester.element(find.text(text)), alignment: 1);
  await _paint(tester);
  final paragraph = tester.getRect(find.text(text));
  final action = tester.getRect(find.widgetWithText(TextButton, deleteLabel));
  expect(paragraph.bottom, lessThanOrEqualTo(action.top));
  expect(paragraph.bottom, greaterThan(0));
  expect(
    find.widgetWithText(TextButton, deleteLabel).hitTestable(),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);
}

final _history = ScheduleEntity(
  id: 'history',
  place: const PlaceEntity(id: 'place', placeName: 'Library'),
  scheduleName: 'Archived appointment',
  scheduleTime: DateTime.utc(2026, 9, 1, 9),
  timeZoneId: 'UTC',
  occurrenceOffsetSeconds: 0,
  moveTime: Duration.zero,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
  isStarted: false,
  isChanged: true,
  doneStatus: ScheduleDoneStatus.normalEnd,
);

class _ScriptedDeletion extends Fake implements DeleteScheduleUseCase {
  int generation = 0;
  int prepares = 0;
  int confirms = 0;
  int retries = 0;
  RecurringEditScope? lastScope;
  Object? prepareFailure;
  Object? confirmFailure;
  Completer<ScheduleDeletionIntent>? preparation;
  Completer<ScheduleDeletionResult>? completion;
  void Function(ScheduleDeletionCommit)? commitObserver;
  ScheduleDeletionCleanup nextCleanup = ScheduleDeletionCleanup.complete;
  var intent = ScheduleDeletionIntent(
    intentId: 'confirmation',
    snapshot: ScheduleEditSnapshot(
      _history,
      const PreparationEntity(preparationStepList: []),
      const ScheduleEditBaseline(
        store: 'store',
        generation: 0,
        revision: 1,
        incarnation: 'history-incarnation',
        version: 4,
      ),
    ),
    scope: RecurringEditScope.occurrence,
    targets: const [
      ScheduleDeletionTarget(
        id: 'history',
        incarnation: 'history-incarnation',
        version: 4,
      ),
    ],
  );
  var commit = ScheduleDeletionCommit(
    scheduleId: 'history',
    store: 'store',
    generation: 0,
    removedIds: {'history'},
    changed: true,
    alreadyAbsent: false,
  );
  ScheduleDeletionResult get result =>
      ScheduleDeletionResult(commit: commit, cleanup: nextCleanup);
  @override
  int get currentGeneration => generation;
  @override
  bool isCurrentGeneration(int value) => generation == value;
  @override
  Future<ScheduleDeletionIntent> prepare(
    String id, {
    RecurringEditScope scope = RecurringEditScope.occurrence,
  }) async {
    prepares++;
    lastScope = scope;
    if (prepareFailure != null) {
      throw prepareFailure!;
    }
    if (preparation != null) {
      return preparation!.future;
    }
    return intent;
  }

  @override
  Future<ScheduleDeletionResult> confirm(
    ScheduleDeletionIntent intent, {
    void Function(ScheduleDeletionCommit)? onCommitted,
  }) async {
    confirms++;
    if (confirmFailure != null) {
      throw confirmFailure!;
    }
    commitObserver = onCommitted;
    if (completion != null) {
      return completion!.future;
    }
    onCommitted?.call(commit);
    return result;
  }

  @override
  Future<ScheduleDeletionResult> retryCleanup(
    ScheduleDeletionCommit commit,
  ) async {
    retries++;
    return result;
  }
}
