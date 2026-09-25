import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/default_preferences.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/use-cases/default_preferences_workflow.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/bloc/default_preparation_spare_time_form_bloc.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/preparation_spare_time_edit_screen.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class TestPreferencesWorkflow extends Fake
    implements DefaultPreferencesWorkflow {
  PreparationEntity preparation = const PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'step',
        preparationName: 'Shower',
        preparationTime: Duration(minutes: 5),
      ),
    ],
  );
  Duration spare = const Duration(minutes: 10);
  @override
  int generation = 0;
  int saves = 0;
  int retries = 0;
  Future<DefaultPreferencesSnapshot> Function()? readHandler;
  Future<DefaultPreferencesSaveReceipt> Function(DefaultPreferencesSubmission)?
  saveHandler;
  Future<DefaultPreferencesSaveReceipt> Function(DefaultPreferencesSaveReceipt)?
  retryHandler;
  DefaultPreferencesSubmission? submitted;
  @override
  bool isGenerationCurrent(int value) => value == generation;
  @override
  Future<DefaultPreferencesSnapshot> read() async =>
      await readHandler?.call() ?? snapshot;
  DefaultPreferencesSnapshot get snapshot => DefaultPreferencesSnapshot(
    preparation: preparation,
    spareTime: spare,
    store: 'store',
    generation: generation,
    revision: 1,
  );
  DefaultPreferencesSaveReceipt receipt({
    bool reload = false,
    bool delivery = false,
  }) => DefaultPreferencesSaveReceipt(
    operation: Object(),
    store: 'store',
    generation: generation,
    changed: true,
    revision: 2,
    reloadPending: reload,
    deliveryPending: delivery,
  );
  @override
  Future<DefaultPreferencesSaveReceipt> save(
    DefaultPreferencesSubmission input,
  ) async {
    saves++;
    submitted = input;
    return await saveHandler?.call(input) ?? receipt();
  }

  @override
  Future<DefaultPreferencesSaveReceipt> retry(
    DefaultPreferencesSaveReceipt value,
  ) async {
    retries++;
    return await retryHandler?.call(value) ??
        value.withFollowUp(reloadPending: false, deliveryPending: false);
  }
}

void main() {
  late TestPreferencesWorkflow workflow;
  setUp(() async {
    await getIt.reset();
    workflow = TestPreferencesWorkflow();
    getIt.registerFactory<DefaultPreparationSpareTimeFormBloc>(
      () => DefaultPreparationSpareTimeFormBloc(workflow),
    );
    getIt.registerFactory<PreparationFormBloc>(PreparationFormBloc.new);
  });
  tearDown(() async {
    await getIt.reset();
  });
  Future<void> pump(
    WidgetTester tester, {
    String locale = 'ko',
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PreparationSpareTimeEditScreen(),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'coherent initial values and edits remain mounted across spare changes',
    (tester) async {
      workflow.spare = const Duration(minutes: 3);
      await pump(tester);
      expect(find.text('3분'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Coffee');
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('8분'), findsOneWidget);
    },
  );
  testWidgets(
    'safe save failure preserves edited preparation without raw exception',
    (tester) async {
      workflow.saveHandler = (_) async =>
          throw StateError('/private/path secret');
      await pump(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Coffee');
      await save(tester);
      expect(find.byType(PreparationSpareTimeEditScreen), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.textContaining('저장하지 못했어요'), findsOneWidget);
      expect(find.textContaining('/private/path'), findsNothing);
    },
  );
  testWidgets('save waits and repeated taps cannot submit twice', (
    tester,
  ) async {
    final pending = Completer<DefaultPreferencesSaveReceipt>();
    workflow.saveHandler = (_) => pending.future;
    await pump(tester);
    await tester.tap(find.byType(TextButton).first);
    await tester.pump();
    await tester.tap(find.byType(TextButton).first);
    await tester.pump();
    expect(workflow.saves, 1);
    expect(find.byType(PreparationSpareTimeEditScreen), findsOneWidget);
    pending.complete(workflow.receipt());
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
  testWidgets('changed step time is submitted through the concrete workflow', (
    tester,
  ) async {
    await pump(tester);
    tester
        .element(find.byType(TextFormField).first)
        .read<PreparationFormBloc>()
        .add(
          const PreparationFormPreparationStepTimeChanged(
            index: 0,
            preparationStepTime: Duration(minutes: 15),
          ),
        );
    await tester.pumpAndSettle();
    await save(tester);
    expect(
      workflow.submitted!.preparation.totalDuration,
      const Duration(minutes: 15),
    );
  });
  testWidgets('partial save locks input and retries only its receipt', (
    tester,
  ) async {
    workflow.saveHandler = (_) async => workflow.receipt(reload: true);
    await pump(tester);
    await save(tester);
    expect(find.textContaining('설정은 저장되었지만'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add).first, warnIfMissed: false);
    await tester.pump();
    expect(find.text('10분'), findsOneWidget);
    await tester.tap(find.text('남은 작업 다시 시도'));
    await tester.pumpAndSettle();
    expect(workflow.saves, 1);
    expect(workflow.retries, 1);
    expect(find.text('open'), findsOneWidget);
  });
  testWidgets(
    'authority verification failure stays saved and exposes a safe retry',
    (tester) async {
      workflow.saveHandler = (_) async => workflow.receipt().withFollowUp(
        reloadPending: false,
        deliveryPending: false,
        authorityPending: true,
      );
      await pump(tester);
      await save(tester);
      expect(find.textContaining('현재 로컬 데이터를 확인하지 못했어요'), findsOneWidget);
      expect(find.textContaining('교체되었어요'), findsNothing);
      await tester.tap(find.text('남은 작업 다시 시도'));
      await tester.pumpAndSettle();
      expect(workflow.saves, 1);
      expect(workflow.retries, 1);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets(
    'stale draft reload cancellation and failed reload preserve input',
    (tester) async {
      workflow.saveHandler = (_) async =>
          throw const DefaultPreferencesRejected(
            DefaultPreferencesFailure.conflict,
          );
      await pump(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Coffee');
      await save(tester);
      await tester.tap(find.text('최신 설정 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.byType(TwoActionDialog), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsOneWidget);
      workflow.readHandler = () async => throw StateError('private');
      await tester.tap(find.text('최신 설정 다시 불러오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('최신 설정 다시 불러오기').last);
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.textContaining('일정 또는 설정'), findsOneWidget);
      workflow.readHandler = null;
      workflow.preparation = const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'new',
            preparationName: 'Latest',
            preparationTime: Duration(minutes: 8),
          ),
        ],
      );
      await tester.tap(find.text('최신 설정 다시 불러오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('최신 설정 다시 불러오기').last);
      await tester.pumpAndSettle();
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);
    },
  );
  testWidgets('initial load failure has a real retry and no endless spinner', (
    tester,
  ) async {
    workflow.readHandler = () async => throw StateError('hidden');
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('불러오지 못했어요'), findsOneWidget);
    workflow.readHandler = null;
    await tester.tap(find.text('최신 설정 다시 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('Shower'), findsOneWidget);
  });
  testWidgets(
    'disposed route cannot pop a later route on old save completion',
    (tester) async {
      final pending = Completer<DefaultPreferencesSaveReceipt>();
      workflow.saveHandler = (_) => pending.future;
      await pump(tester);
      await tester.tap(find.byType(TextButton).first);
      await tester.pump();
      final navigator = Navigator.of(
        tester.element(find.byType(PreparationSpareTimeEditScreen)),
      );
      navigator.pop();
      await tester.pumpAndSettle();
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('later route')),
        ),
      );
      await tester.pumpAndSettle();
      pending.complete(workflow.receipt());
      await tester.pumpAndSettle();
      expect(find.text('later route'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'restore during save keeps superseded receipt from auto popping',
    (tester) async {
      final pending = Completer<DefaultPreferencesSaveReceipt>();
      workflow.saveHandler = (_) => pending.future;
      await pump(tester);
      await tester.tap(find.byType(TextButton).first);
      await tester.pump();
      final old = workflow.receipt();
      workflow.generation++;
      pending.complete(old);
      await tester.pumpAndSettle();
      expect(find.byType(PreparationSpareTimeEditScreen), findsOneWidget);
      expect(find.textContaining('로컬 작업 상태가 달라'), findsOneWidget);
    },
  );
  for (final locale in ['ko', 'en']) {
    testWidgets('$locale 200 percent pending and conflict states fit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      workflow.saveHandler = (_) async =>
          workflow.receipt(reload: true, delivery: true);
      await pump(tester, locale: locale, scale: 2);
      await save(tester);
      expect(
        find.byKey(const ValueKey('default_preferences_notice')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
