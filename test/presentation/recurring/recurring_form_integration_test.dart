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
import 'package:on_time_front/domain/use-cases/create_custom_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_form_submission_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedule_form_draft_use_case.dart';
import 'package:on_time_front/domain/use-cases/recurring_schedules_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';
import 'package:on_time_front/domain/use-cases/update_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_form_submission_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';
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
    const ScheduleFormCreated(confirmed: true),
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
    final useCase = RecurringSchedulesUseCase(recurring, schedules, alarms);
    var nextId = 0;
    bloc = ScheduleFormBloc(
      LoadScheduleFormDraftUseCase.withOverrides(
        LoadPreparationByScheduleIdUseCase(preparations),
        GetPreparationByScheduleIdUseCase(preparations),
        GetDefaultPreparationUseCase(preparations),
        GetScheduleByIdUseCase(schedules),
        now: () => now,
        newId: () => 'new-${nextId++}',
        timeZoneId: () async => 'UTC',
      ),
      CreateScheduleFormSubmissionUseCase(
        CreateScheduleWithPlaceUseCase(schedules, alarms),
        CreateCustomPreparationUseCase(preparations),
        recurringSchedules: useCase,
      ),
      UpdateScheduleFormSubmissionUseCase(
        UpdateScheduleUseCase(schedules, alarms),
        UpdatePreparationByScheduleIdUseCase(preparations),
        recurringSchedules: useCase,
      ),
      recurringSchedules: useCase,
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
        if (step == 0) {
          await captureRefresh(tester, 'date-time');
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/goldens/recurring_date_time_390x844.png',
            ),
          );
        }
        if (step == 2) {
          await captureRefresh(tester, 'preparation');
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/goldens/recurring_preparation_390x844.png',
            ),
          );
        }
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
        const ScheduleFormUpdated(confirmed: true),
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
  final operations = <ScheduleMutationAlarmOperation>[];
  @override
  Future<void> call({
    required ScheduleMutationAlarmOperation operation,
    required String scheduleId,
  }) async {
    operations.add(operation);
  }
}
