import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/shared/components/step_progress.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/domain/use-cases/schedule_save_workflow.dart';
import '../../helpers/refresh_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/presentation/schedule_create/components/schedule_multi_page_form.dart';
import 'package:on_time_front/presentation/schedule_create/components/top_bar.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/repositories/alarm_repository_impl.dart';
import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_form_submission_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedule_form_draft_use_case.dart';
import 'package:on_time_front/domain/use-cases/recurring_schedules_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_form_submission_use_case.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';

void main() {
  setUpAll(loadRefreshFonts);
  late AppDatabase db;
  late PreparationRepositoryImpl preparations;
  late ScheduleRepositoryImpl schedules;
  late RecurringScheduleRepositoryImpl recurring;
  late _AlarmEffects alarms;
  late ScheduleFormBloc bloc;
  final now = DateTime.utc(2030, 1, 1);
  final start = DateTime.utc(2030, 1, 2, 9);
  final rule = RecurrenceRule(
    frequency: RecurrenceFrequency.daily,
    start: start,
    timeZoneId: 'UTC',
    count: 3,
  );

  Future<void> event(
    ScheduleFormEvent value,
    bool Function(ScheduleFormState) done,
  ) async {
    final settled = bloc.stream.firstWhere(done);
    bloc.add(value);
    await settled.timeout(const Duration(seconds: 5));
  }

  Future<void> draft() async {
    await event(
      ScheduleFormCreateRequested(
        initialDate: start,
        currentUserSpareTime: const Duration(minutes: 5),
      ),
      (s) => s.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormScheduleNameChanged(scheduleName: '출근'));
    bloc.add(const ScheduleFormPlaceNameChanged(placeName: '회사'));
    bloc.add(
      const ScheduleFormMoveTimeChanged(moveTime: Duration(minutes: 20)),
    );
    bloc.add(
      ScheduleFormScheduleDateTimeChanged(
        scheduleDate: start,
        scheduleTime: start,
        occurrenceOffsetSeconds: 0,
      ),
    );
    await event(
      ScheduleFormRecurringChanged(rule),
      (s) => s.recurrenceRule != null,
    );
  }

  Future<void> review() => event(
    const ScheduleFormCreated(),
    (s) => s.submissionStatus == ScheduleFormSubmissionStatus.review,
  );
  Future<void> save() => event(
    ScheduleFormRecurrenceReviewConfirmed(bloc.state.recurrenceReview!),
    (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
    final source = PreparationLocalDataSourceImpl(appDatabase: db);
    await source.createDefaultPreparation(
      _preparation('기본 준비', 25),
      userId: 'local-profile',
    );
    preparations = PreparationRepositoryImpl(
      preparationLocalDataSource: source,
      userRepository: _UnusedUser(),
      database: db,
    );
    recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
    schedules = ScheduleRepositoryImpl(
      database: db,
      timedPreparationRepository: _UnusedTimers(),
      recurringScheduleRepository: recurring,
    );
    alarms = _AlarmEffects();
    final useCase = RecurringSchedulesUseCase(
      recurring,
      schedules,
      alarms,
      _UnusedDeletion(),
    );
    final aggregate = ScheduleAggregateRepositoryImpl(
      db,
      recurring,
      now: () => now,
    );
    final workflow = ScheduleSaveWorkflow(aggregate, alarms);
    var nextId = 0;
    bloc = ScheduleFormBloc(
      LoadScheduleFormDraftUseCase.withOverrides(
        LoadPreparationByScheduleIdUseCase(preparations),
        GetPreparationByScheduleIdUseCase(preparations),
        GetDefaultPreparationUseCase(preparations),
        GetScheduleByIdUseCase(schedules),
        aggregate: aggregate,
        now: () => now,
        newId: () => 'new-${nextId++}',
        timeZoneId: () async => 'UTC',
      ),
      CreateScheduleFormSubmissionUseCase(workflow),
      UpdateScheduleFormSubmissionUseCase(workflow),
      aggregate: aggregate,
      recurringSchedules: useCase,
      now: () => now,
    );
  });
  tearDown(() async {
    await bloc.close();
    await schedules.dispose();
    await preparations.dispose();
    await db.close();
  });

  testWidgets(
    'four-step creation opens recurrence review and saves to the local database',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(draft);
      final byDate = GetSchedulesByDateUseCase(schedules);
      getIt.registerFactoryParam<ScheduleDateTimeCubit, ScheduleFormBloc, void>(
        (form, _) => ScheduleDateTimeCubit(
          form,
          LoadAdjacentScheduleWithPreparationUseCase(
            LoadSchedulesByDateUseCase(schedules),
            byDate,
            LoadPreparationByScheduleIdUseCase(preparations),
          ),
          GetAdjacentSchedulesWithPreparationUseCase(
            byDate,
            GetPreparationByScheduleIdUseCase(preparations),
          ),
        ),
      );
      addTearDown(getIt.reset);
      bool? saved;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeData,
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: BlocProvider.value(
                          value: bloc,
                          child: ScheduleMultiPageForm(
                            onSaved: () =>
                                bloc.add(const ScheduleFormCreated()),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (var step = 0; step < 3; step++) {
        for (var attempt = 0; attempt < 20; attempt++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          });
          await tester.pump(const Duration(milliseconds: 20));
          if (tester.widget<TopBar>(find.byType(TopBar)).isNextButtonEnabled) {
            break;
          }
        }
        expect(
          tester.widget<TopBar>(find.byType(TopBar)).isNextButtonEnabled,
          isTrue,
          reason: 'Step $step: ${bloc.state}',
        );
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
        if (step == 0) await captureRefresh(tester, 'date-time');
        if (step == 2) await captureRefresh(tester, 'preparation');
      }
      expect(find.text('검토하기'), findsOneWidget);
      final reviewed = bloc.stream.firstWhere(
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.review,
      );
      await tester.tap(find.text('검토하기'));
      await tester.runAsync(() => reviewed);
      await tester.pumpAndSettle();
      expect(find.text('반복 일정 확인'), findsOneWidget);
      expect(find.text('반복 3회'), findsOneWidget);
      expect(
        await tester.runAsync(() => db.scheduleDao.getScheduleList()),
        isEmpty,
      );
      final success = bloc.stream.firstWhere(
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      await tester.tap(find.text('저장하기'));
      await tester.runAsync(() => success);
      await tester.pumpAndSettle();
      expect(saved, isTrue);
      expect(
        await tester.runAsync(() => db.scheduleDao.getScheduleList()),
        hasLength(3),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'form review and cancel write nothing; confirmation saves owned preparation and alarms',
    () async {
      await draft();
      await review();
      expect(await db.scheduleDao.getScheduleList(), isEmpty);
      expect(await recurring.getSegments(), isEmpty);
      expect(alarms.operations, isEmpty);
      await event(
        const ScheduleFormReviewDismissed(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.idle,
      );
      expect(bloc.state.scheduleName, '출근');
      await review();
      expect(bloc.state.recurrenceReview!.totalOccurrences, 3);
      await save();
      final rows = await schedules.getSchedulesByDate(
        start,
        DateTime.utc(2031),
      );
      expect(rows, hasLength(3));
      expect(alarms.operations, [ScheduleMutationAlarmOperation.created]);
      await preparations.updateDefaultPreparation(_preparation('새 기본 준비', 60));
      await preparations.getPreparationByScheduleId(rows.first.id);
      final owned =
          (await preparations.preparationStream.first)[rows.first.id]!;
      expect(owned.preparationStepList.single.preparationName, '기본 준비');
      expect(owned.totalDuration, const Duration(minutes: 25));
      final alarmsRepository = AlarmRepositoryImpl(
        database: db,
        scheduleRepository: schedules,
        preparationRepository: preparations,
        recurringScheduleRepository: recurring,
      );
      final window = await alarmsRepository.getAlarmWindow(
        now,
        DateTime.utc(2031),
      );
      expect(window, hasLength(3));
      expect(
        window.first.preparation.totalDuration,
        const Duration(minutes: 25),
      );
      // A retry of the same accepted submission must not create another series.
      await save();
      expect(await recurring.getSegments(), hasLength(1));
      expect(await db.scheduleDao.getScheduleList(), hasLength(3));
    },
  );

  test(
    'following edit loads the series base and preserves an individual name override',
    () async {
      await draft();
      await review();
      await save();
      final rows = await schedules.getSchedulesByDate(
        start,
        DateTime.utc(2031),
      );
      final second = rows[1];
      final prep = await recurring.getPreparation(
        second.preparationDefinitionId!,
      );
      await recurring.updateOccurrence(
        second,
        second.copyWith(scheduleName: '개별 변경'),
        prep,
        preparationChanged: false,
      );
      await event(
        ScheduleFormEditRequested(
          scheduleId: second.id,
          scope: RecurringEditScope.following,
        ),
        (s) =>
            s.status == ScheduleFormStatus.success &&
            s.originalSchedule != null,
      );
      expect(bloc.state.scheduleName, '출근');
      expect(bloc.state.originalSchedule!.scheduleName, '개별 변경');
      expect(bloc.state.recurringScope, RecurringEditScope.following);
      bloc.add(const ScheduleFormScheduleNameChanged(scheduleName: '이후 출근'));
      await event(
        const ScheduleFormUpdated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.review,
      );
      expect(bloc.state.recurrenceReview!.totalOccurrences, 2);
      expect(
        bloc
            .state
            .recurrenceReview!
            .occurrences
            .values
            .first
            .schedule
            .scheduleName,
        '개별 변경',
      );
      await event(
        ScheduleFormRecurrenceReviewConfirmed(bloc.state.recurrenceReview!),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      final after = await schedules.getSchedulesByDate(
        start,
        DateTime.utc(2031),
      );
      expect(after.map((s) => s.scheduleName), ['출근', '개별 변경', '이후 출근']);
    },
  );

  test(
    'invalid preparation keeps the draft and allows a successful retry',
    () async {
      await draft();
      await event(
        const ScheduleFormPreparationChanged(
          preparation: PreparationEntity(preparationStepList: []),
        ),
        (s) => s.preparation!.preparationStepList.isEmpty,
      );
      await event(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.failure,
      );
      expect(bloc.state.scheduleName, '출근');
      expect(bloc.state.submissionError, contains('준비'));
      expect(await recurring.getSegments(), isEmpty);
      expect(await db.scheduleDao.getScheduleList(), isEmpty);
      await event(
        ScheduleFormPreparationChanged(preparation: _preparation('수정한 준비', 15)),
        (s) => s.preparation!.totalDuration == const Duration(minutes: 15),
      );
      await review();
      await save();
      expect(await db.scheduleDao.getScheduleList(), hasLength(3));
      expect(alarms.operations, [ScheduleMutationAlarmOperation.created]);
    },
  );
  for (final language in ['ko', 'en']) {
    testWidgets('ordinary save rollback and delivery-only retry $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(draft);
      await tester.runAsync(
        () => event(
          const ScheduleFormRecurringChanged(null),
          (s) => s.recurrenceRule == null,
        ),
      );
      final byDate = GetSchedulesByDateUseCase(schedules);
      getIt.registerFactoryParam<ScheduleDateTimeCubit, ScheduleFormBloc, void>(
        (form, _) => ScheduleDateTimeCubit(
          form,
          LoadAdjacentScheduleWithPreparationUseCase(
            LoadSchedulesByDateUseCase(schedules),
            byDate,
            LoadPreparationByScheduleIdUseCase(preparations),
          ),
          GetAdjacentSchedulesWithPreparationUseCase(
            byDate,
            GetPreparationByScheduleIdUseCase(preparations),
          ),
        ),
      );
      addTearDown(getIt.reset);
      bool? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: BlocProvider.value(
                          value: bloc,
                          child: ScheduleMultiPageForm(
                            onSaved: () =>
                                bloc.add(const ScheduleFormCreated()),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (var page = 0; page < 3; page++) {
        for (
          var attempt = 0;
          attempt < 30 &&
              (tester
                          .widget<ScreenActions>(find.byType(ScreenActions))
                          .onAction ==
                      null ||
                  !bloc.state.isValid);
          attempt++
        ) {
          await tester.runAsync(() => db.customSelect('SELECT 1').get());
          await tester.pump();
        }
        expect(
          bloc.state.isValid,
          isTrue,
          reason: 'Page $page must be valid before tapping Next',
        );
        await tester.pump();
        expect(
          tester.widget<ScreenActions>(find.byType(ScreenActions)).onAction,
          isNotNull,
        );
        await tester.tap(find.text(language == 'ko' ? '다음' : 'Next'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(
          tester.widget<StepProgress>(find.byType(StepProgress)).currentStep,
          page + 1,
          reason: 'Next should advance actual form page $page',
        );
      }
      final before = await tester.runAsync(
        () async => (await db.select(db.users).getSingle()).dataRevision,
      );
      await tester.runAsync(
        () => db.customStatement(
          "CREATE TRIGGER fail_save BEFORE UPDATE OF data_revision ON users BEGIN SELECT RAISE(ABORT,'injected save fault'); END",
        ),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      final submittedMutation = bloc.state.mutationId;
      final observedStatuses = <ScheduleFormSubmissionStatus>[];
      final observation = bloc.stream
          .map((state) => state.submissionStatus)
          .distinct()
          .listen(observedStatuses.add);
      addTearDown(observation.cancel);
      final submittedOwner = bloc.formOwner;
      final timeReviewed = bloc.stream.firstWhere(
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
      );
      await tester.tap(find.text(language == 'ko' ? '저장' : 'Save'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => timeReviewed.timeout(const Duration(seconds: 5)),
      );
      await tester.pumpAndSettle();
      expect(
        bloc.state.submissionStatus,
        ScheduleFormSubmissionStatus.timeReview,
      );
      final confirm = find.byKey(
        const ValueKey('schedule-time-review-confirm'),
      );
      void describeConfirmation(String phase) {
        final elements = confirm.evaluate().toList();
        final form = find.byType(ScheduleMultiPageForm).evaluate().toList();
        debugPrint(
          'U02 $language $phase: status=${bloc.state.submissionStatus} '
          'keyCount=${elements.length} hitCount=${confirm.hitTestable().evaluate().length} '
          'view=${tester.view.physicalSize} insetsBottom=${tester.view.viewInsets.bottom} '
          'alertCount=${find.byType(AlertDialog).evaluate().length} '
          'formRouteCurrent=${form.isEmpty ? null : ModalRoute.of(form.single)?.isCurrent} '
          'reviewNull=${bloc.state.timeReview == null} '
          'ownerSame=${identical(submittedOwner, bloc.formOwner)} '
          'mutationSame=${submittedMutation == bloc.state.mutationId} '
          'statuses=$observedStatuses '
          'rect=${elements.isEmpty ? null : tester.getRect(confirm)} '
          'routeCurrent=${elements.isEmpty ? null : ModalRoute.of(elements.single)?.isCurrent}',
        );
      }

      describeConfirmation('after explicit review stream and settle');
      // A Bloc event may finish after pumpAndSettle saw no scheduled frame.
      // Give its listener and the dialog route bounded frames to render.
      for (
        var frame = 0;
        frame < 20 && confirm.hitTestable().evaluate().isEmpty;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      describeConfirmation('after bounded dialog frames');
      expect(confirm, findsOneWidget);
      expect(confirm.hitTestable(), findsOneWidget);
      expect(
        await tester.runAsync(() => db.select(db.schedules).get()),
        isEmpty,
      );
      final failed = bloc.stream.firstWhere(
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.failure,
      );
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(() => failed.timeout(const Duration(seconds: 5)));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => db.select(db.schedules).get()),
        isEmpty,
      );
      expect(bloc.state.scheduleName, '출근');
      expect(saved, isNull);
      await captureA08(tester, '$language-rollback');
      await tester.runAsync(() => db.customStatement('DROP TRIGGER fail_save'));
      alarms.deliveryComplete = false;
      final pending = bloc.stream.firstWhere(
        (s) =>
            s.submissionStatus == ScheduleFormSubmissionStatus.deliveryPending,
      );
      await tester.tap(
        find.text(language == 'ko' ? '다시 저장하기' : 'Retry saving'),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(() => pending.timeout(const Duration(seconds: 5)));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => db.select(db.schedules).get()),
        hasLength(1),
      );
      expect(
        await tester.runAsync(
          () async => (await db.select(db.users).getSingle()).dataRevision,
        ),
        before! + 1,
      );
      expect(saved, isNull);
      expect(
        observedStatuses.where(
          (s) => s == ScheduleFormSubmissionStatus.timeReview,
        ),
        hasLength(1),
      );
      expect(
        find.byKey(const ValueKey('schedule-time-review-confirm')),
        findsNothing,
      );
      expect(bloc.state.saveReceipt!.mutationId, submittedMutation);
      final pendingReceipt = bloc.state.saveReceipt!;
      await captureA08(tester, '$language-delivery-pending');
      alarms.deliveryComplete = true;
      final done = bloc.stream.firstWhere(
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
      await tester.tap(find.text(l.dataRetry));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(() => done.timeout(const Duration(seconds: 5)));
      await tester.pumpAndSettle();
      expect(saved, isTrue);
      expect(
        observedStatuses.where(
          (s) => s == ScheduleFormSubmissionStatus.timeReview,
        ),
        hasLength(1),
      );
      expect(bloc.state.saveReceipt!.mutationId, pendingReceipt.mutationId);
      expect(bloc.state.saveReceipt!.generation, pendingReceipt.generation);
      expect(bloc.state.saveReceipt!.scheduleId, pendingReceipt.scheduleId);
      expect(
        await tester.runAsync(() => db.select(db.schedules).get()),
        hasLength(1),
      );
      expect(
        await tester.runAsync(
          () async => (await db.select(db.users).getSingle()).dataRevision,
        ),
        before + 1,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final modal in ['review', 'receipt']) {
    testWidgets('late $modal answer cannot submit or close replacement draft', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(draft);
      final byDate = GetSchedulesByDateUseCase(schedules);
      getIt.registerFactoryParam<ScheduleDateTimeCubit, ScheduleFormBloc, void>(
        (form, _) => ScheduleDateTimeCubit(
          form,
          LoadAdjacentScheduleWithPreparationUseCase(
            LoadSchedulesByDateUseCase(schedules),
            byDate,
            LoadPreparationByScheduleIdUseCase(preparations),
          ),
          GetAdjacentSchedulesWithPreparationUseCase(
            byDate,
            GetPreparationByScheduleIdUseCase(preparations),
          ),
        ),
      );
      addTearDown(getIt.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: ScheduleMultiPageForm(
                onSaved: () => bloc.add(const ScheduleFormCreated()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (modal == 'receipt') {
        await tester.runAsync(
          () => event(
            const ScheduleFormRecurringChanged(null),
            (s) => s.recurrenceRule == null,
          ),
        );
        alarms.deliveryComplete = false;
      }
      await tester.runAsync(
        () => event(
          const ScheduleFormCreated(),
          (s) =>
              s.submissionStatus ==
              (modal == 'review'
                  ? ScheduleFormSubmissionStatus.review
                  : ScheduleFormSubmissionStatus.timeReview),
        ),
      );
      await tester.pumpAndSettle();
      if (modal == 'receipt') {
        final pending = bloc.stream.firstWhere(
          (s) =>
              s.submissionStatus ==
              ScheduleFormSubmissionStatus.deliveryPending,
        );
        final confirm = find.byKey(
          const ValueKey('schedule-time-review-confirm'),
        );
        expect(confirm.hitTestable(), findsOneWidget);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => pending.timeout(const Duration(seconds: 5)),
        );
        await tester.pumpAndSettle();
      }
      final previousOwner = bloc.formOwner;
      await tester.runAsync(draft);
      await tester.pump();
      final currentId = bloc.state.id;
      expect(identical(previousOwner, bloc.formOwner), isFalse);
      final label = modal == 'review'
          ? '저장하기'
          : AppLocalizations.of(
              tester.element(find.byType(AlertDialog)),
            )!.dataRetry;
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      await tester.pump();
      expect(bloc.state.id, currentId);
      expect(bloc.state.submissionStatus, ScheduleFormSubmissionStatus.idle);
      expect(bloc.state.saveReceipt, isNull);
      expect(find.byType(ScheduleMultiPageForm), findsOneWidget);
      expect(
        await tester.runAsync(() => db.select(db.schedules).get()),
        hasLength(modal == 'review' ? 0 : 1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test(
    'partial receipt from form A cannot replace actual save of new form B',
    () async {
      await draft();
      await event(
        const ScheduleFormRecurringChanged(null),
        (s) => s.recurrenceRule == null,
      );
      alarms.deliveryComplete = false;
      await event(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
      );
      await event(
        ScheduleFormTimeReviewConfirmed(bloc.state.timeReview!),
        (s) =>
            s.submissionStatus == ScheduleFormSubmissionStatus.deliveryPending,
      );
      final first = bloc.state.id;
      expect(bloc.state.saveReceipt, isNotNull);
      await draft();
      await event(
        const ScheduleFormRecurringChanged(null),
        (s) => s.recurrenceRule == null,
      );
      expect(bloc.state.id, isNot(first));
      expect(bloc.state.saveReceipt, isNull);
      expect(bloc.state.originalSchedule, isNull);
      alarms.deliveryComplete = true;
      await event(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
      );
      await event(
        ScheduleFormTimeReviewConfirmed(bloc.state.timeReview!),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      expect(await db.select(db.schedules).get(), hasLength(2));
    },
  );
}

PreparationEntity _preparation(String name, int minutes) => PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: 'source-$minutes',
      preparationName: name,
      preparationTime: Duration(minutes: minutes),
    ),
  ],
);

class _UnusedUser extends Fake implements UserRepository {}

class _UnusedTimers extends Fake implements TimedPreparationRepository {}

class _AlarmEffects implements ScheduleMutationAlarmEffectsCoordinator {
  bool deliveryComplete = true;
  final operations = <ScheduleMutationAlarmOperation>[];
  @override
  Future<bool> afterCommit() async {
    operations.add(ScheduleMutationAlarmOperation.created);
    return deliveryComplete;
  }

  @override
  Future<void> call({
    required ScheduleMutationAlarmOperation operation,
    required String scheduleId,
  }) async {
    operations.add(operation);
  }
}

Future<void> captureA08(WidgetTester tester, String name) async {
  const path = String.fromEnvironment('A08_CAPTURE_DIR');
  if (path.isEmpty) return;
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final image = await (view.debugLayer! as OffsetLayer).toImage(
      Offset.zero & view.size,
      pixelRatio: 1,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(path).create(recursive: true);
    await File('$path/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _UnusedDeletion extends Fake implements DeleteScheduleUseCase {}
