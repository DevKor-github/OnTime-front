import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/schedule_multi_page_form.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import '../../helpers/u02_save_fixture.dart';

class _LoadAdjacent extends Fake
    implements LoadAdjacentScheduleWithPreparationUseCase {
  @override
  Future<void> call({
    required DateTime startDate,
    required DateTime endDate,
  }) async {}
}

class _Adjacent extends Fake
    implements GetAdjacentSchedulesWithPreparationUseCase {
  bool hold = false;
  final requests =
      <(DateTime, Completer<AdjacentSchedulesWithPreparationEntity>)>[];
  @override
  Future<AdjacentSchedulesWithPreparationEntity> call({
    required DateTime selectedDateTime,
    String? currentScheduleId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    if (!hold) {
      return Future.value(const AdjacentSchedulesWithPreparationEntity());
    }
    final pending = Completer<AdjacentSchedulesWithPreparationEntity>();
    requests.add((selectedDateTime, pending));
    return pending.future;
  }
}

void main() {
  late U02SaveFixture f;
  late _Adjacent adjacent;
  late ScheduleDateTimeCubit dateCubit;
  setUp(() async {
    await getIt.reset();
    f = U02SaveFixture();
    await f.open();
    await f.draft(-14400);
    final date = DateTime.utc(2030, 1, 2, 10);
    await f.send(
      ScheduleFormScheduleDateTimeChanged(
        scheduleDate: date,
        scheduleTime: date,
        timeZoneId: 'UTC',
        timeZoneExplicitlySelected: true,
        occurrenceOffsetSeconds: 0,
      ),
      (s) => s.timeZoneId == 'UTC',
    );
    adjacent = _Adjacent();
    getIt.registerFactoryParam<ScheduleDateTimeCubit, ScheduleFormBloc, void>((
      form,
      _,
    ) {
      dateCubit = ScheduleDateTimeCubit(form, _LoadAdjacent(), adjacent);
      return dateCubit;
    });
  });
  tearDown(() async {
    for (final request in adjacent.requests) {
      if (!request.$2.isCompleted) {
        request.$2.complete(const AdjacentSchedulesWithPreparationEntity());
      }
    }
    await getIt.reset();
    await f.close();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: f.bloc,
            child: ScheduleMultiPageForm(
              onSaved: () => f.bloc.add(const ScheduleFormCreated()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'same form owner cannot confirm an open time review after store generation replacement',
    (tester) async {
      await mount(tester);
      final owner = f.bloc.formOwner;
      final mutation = f.bloc.state.mutationId;
      final revision = await tester.runAsync(f.revision);
      await tester.runAsync(
        () => f.send(
          const ScheduleFormCreated(),
          (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
        ),
      );
      await tester.pumpAndSettle();
      final confirm = find.byKey(
        const ValueKey('schedule-time-review-confirm'),
      );
      expect(confirm.hitTestable(), findsOneWidget);
      final generation = f.bloc.state.timeReview!.baseline!.generation;
      // Exercise the real replacement-generation operation boundary, isolated to
      // this fixture. This is not an actual backup picker or file replacement UI.
      await tester.runAsync(() => f.gate.run(() async {}, replacesData: true));
      expect(f.gate.generation, generation + 1);
      expect(identical(f.bloc.formOwner, owner), isTrue);
      expect(f.bloc.state.mutationId, mutation);
      final rejected = f.bloc.stream.firstWhere(
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.failure,
      );
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(() => rejected.timeout(const Duration(seconds: 5)));
      await tester.pumpAndSettle();
      expect(f.bloc.state.saveFailure, ScheduleSaveFailure.conflict);
      expect(
        await tester.runAsync(() => f.db.select(f.db.schedules).get()),
        isEmpty,
      );
      expect(await tester.runAsync(f.revision), revision);
      expect(f.effects.calls, 0);
      expect(f.bloc.state.mutationId, mutation);
      expect(find.byType(ScheduleMultiPageForm), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'late B zone adjacency cannot make conflicting C valid or enable the real form Next action',
    (tester) async {
      await mount(tester);
      // Await the actual form validation stream after a real name edit, rather
      // than assuming asynchronous initialization has reached the listener.
      final ready = f.bloc.state.isValid
          ? Future.value(f.bloc.state)
          : f.bloc.stream.firstWhere((state) => state.isValid);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Authority flow',
      );
      await tester.pump();
      await tester.runAsync(() => ready.timeout(const Duration(seconds: 5)));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ScreenActions>(find.byType(ScreenActions)).onAction,
        isNotNull,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(dateCubit.state.timeZoneId, 'UTC');
      final revision = await tester.runAsync(f.revision);
      adjacent.hold = true;
      final b = dateCubit.timeZoneSelected('America/New_York');
      final c = dateCubit.timeZoneSelected('Asia/Seoul');
      expect(adjacent.requests, hasLength(2));
      expect(adjacent.requests[0].$1, DateTime.utc(2030, 1, 2, 15));
      expect(adjacent.requests[1].$1, DateTime.utc(2030, 1, 2, 1));
      adjacent.requests[1].$2.complete(
        AdjacentSchedulesWithPreparationEntity(
          nextSchedule: ScheduleWithPreparationEntity(
            id: 'conflicting-c',
            place: const PlaceEntity(id: 'place', placeName: 'Fixture'),
            scheduleName: 'C conflict',
            scheduleTime: DateTime.utc(2030, 1, 2, 1, 10),
            timeZoneId: 'UTC',
            occurrenceOffsetSeconds: 0,
            moveTime: const Duration(minutes: 20),
            scheduleSpareTime: Duration.zero,
            isChanged: false,
            isStarted: false,
            scheduleNote: '',
            preparation: const PreparationWithTimeEntity(
              preparationStepList: [],
            ),
          ),
        ),
      );
      await tester.runAsync(() => c);
      await tester.pumpAndSettle();
      expect(dateCubit.state.isOverlapping, isTrue);
      expect(f.bloc.state.isValid, isFalse);
      adjacent.requests[0].$2.complete(
        const AdjacentSchedulesWithPreparationEntity(),
      );
      await tester.runAsync(() => b);
      await tester.pumpAndSettle();
      expect(dateCubit.state.timeZoneId, 'Asia/Seoul');
      expect(dateCubit.state.isOverlapping, isTrue);
      expect(dateCubit.state.nextScheduleName, 'C conflict');
      expect(f.bloc.state.isValid, isFalse);
      expect(dateCubit.scheduleDateTimeSubmitted(), isFalse);
      expect(
        tester.widget<ScreenActions>(find.byType(ScreenActions)).onAction,
        isNull,
      );
      expect(
        await tester.runAsync(() => f.db.select(f.db.schedules).get()),
        isEmpty,
      );
      expect(await tester.runAsync(f.revision), revision);
      expect(f.effects.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
