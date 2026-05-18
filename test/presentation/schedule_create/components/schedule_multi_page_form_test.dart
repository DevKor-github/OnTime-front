import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/create_custom_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/schedule_multi_page_form.dart';
import 'package:on_time_front/presentation/schedule_create/components/top_bar.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_create_screen.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_edit_screen.dart';

class StubAuthBloc extends Mock implements AuthBloc {
  StubAuthBloc(this._state);

  final AuthState _state;

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

class StubLoadPreparationByScheduleIdUseCase
    implements LoadPreparationByScheduleIdUseCase {
  StubLoadPreparationByScheduleIdUseCase(this.handler);

  final Future<void> Function(String scheduleId) handler;

  @override
  Future<void> call(String scheduleId) => handler(scheduleId);
}

class StubGetPreparationByScheduleIdUseCase
    implements GetPreparationByScheduleIdUseCase {
  StubGetPreparationByScheduleIdUseCase(this.handler);

  final Future<PreparationEntity> Function(String scheduleId) handler;

  @override
  Future<PreparationEntity> call(String scheduleId) => handler(scheduleId);
}

class StubGetDefaultPreparationUseCase implements GetDefaultPreparationUseCase {
  StubGetDefaultPreparationUseCase(this.handler);

  final Future<PreparationEntity> Function() handler;

  @override
  Future<PreparationEntity> call() => handler();
}

class StubGetScheduleByIdUseCase implements GetScheduleByIdUseCase {
  StubGetScheduleByIdUseCase(this.handler);

  final Future<ScheduleEntity> Function(String id) handler;

  @override
  Future<ScheduleEntity> call(String id) => handler(id);
}

class StubCreateScheduleWithPlaceUseCase
    implements CreateScheduleWithPlaceUseCase {
  StubCreateScheduleWithPlaceUseCase(this.handler);

  final Future<void> Function(ScheduleEntity schedule) handler;

  @override
  Future<void> call(ScheduleEntity schedule) => handler(schedule);
}

class StubCreateCustomPreparationUseCase
    implements CreateCustomPreparationUseCase {
  StubCreateCustomPreparationUseCase(this.handler);

  final Future<void> Function(PreparationEntity preparation, String scheduleId)
  handler;

  @override
  Future<void> call(PreparationEntity preparationEntity, String scheduleId) {
    return handler(preparationEntity, scheduleId);
  }
}

class StubUpdateScheduleUseCase implements UpdateScheduleUseCase {
  StubUpdateScheduleUseCase(this.handler);

  Future<void> Function(ScheduleEntity schedule) handler;

  @override
  Future<void> call(ScheduleEntity schedule) => handler(schedule);
}

class StubUpdatePreparationByScheduleIdUseCase
    implements UpdatePreparationByScheduleIdUseCase {
  StubUpdatePreparationByScheduleIdUseCase(this.handler);

  final Future<void> Function(PreparationEntity preparation, String scheduleId)
  handler;

  @override
  Future<void> call(PreparationEntity preparationEntity, String scheduleId) {
    return handler(preparationEntity, scheduleId);
  }
}

class StubLoadAdjacentScheduleWithPreparationUseCase
    implements LoadAdjacentScheduleWithPreparationUseCase {
  StubLoadAdjacentScheduleWithPreparationUseCase(this.handler);

  final Future<void> Function({
    required DateTime startDate,
    required DateTime endDate,
  })
  handler;

  @override
  Future<void> call({required DateTime startDate, required DateTime endDate}) {
    return handler(startDate: startDate, endDate: endDate);
  }
}

class StubGetAdjacentSchedulesWithPreparationUseCase
    implements GetAdjacentSchedulesWithPreparationUseCase {
  StubGetAdjacentSchedulesWithPreparationUseCase(this.handler);

  final Future<AdjacentSchedulesWithPreparationEntity> Function({
    required DateTime selectedDateTime,
    String? currentScheduleId,
    required DateTime startDate,
    required DateTime endDate,
  })
  handler;

  @override
  Future<AdjacentSchedulesWithPreparationEntity> call({
    required DateTime selectedDateTime,
    String? currentScheduleId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return handler(
      selectedDateTime: selectedDateTime,
      currentScheduleId: currentScheduleId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}

void main() {
  late StubLoadPreparationByScheduleIdUseCase
  loadPreparationByScheduleIdUseCase;
  late StubGetPreparationByScheduleIdUseCase getPreparationByScheduleIdUseCase;
  late StubGetDefaultPreparationUseCase getDefaultPreparationUseCase;
  late StubGetScheduleByIdUseCase getScheduleByIdUseCase;
  late StubCreateScheduleWithPlaceUseCase createScheduleWithPlaceUseCase;
  late StubCreateCustomPreparationUseCase createCustomPreparationUseCase;
  late StubUpdateScheduleUseCase updateScheduleUseCase;
  late StubUpdatePreparationByScheduleIdUseCase
  updatePreparationByScheduleIdUseCase;
  late StubAuthBloc authBloc;

  late StubLoadAdjacentScheduleWithPreparationUseCase
  loadAdjacentScheduleWithPreparationUseCase;
  late StubGetAdjacentSchedulesWithPreparationUseCase
  getAdjacentSchedulesWithPreparationUseCase;

  final preparation = PreparationEntity(
    preparationStepList: const [
      PreparationStepEntity(
        id: 'prep-1',
        preparationName: 'Shower',
        preparationTime: Duration(minutes: 10),
      ),
    ],
  );

  final schedule = ScheduleEntity(
    id: 'schedule-1',
    place: PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Meeting',
    scheduleTime: DateTime(2027, 3, 20, 9, 0),
    moveTime: const Duration(minutes: 30),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 10),
    scheduleNote: 'bring laptop',
  );

  ScheduleFormBloc buildBloc() {
    return ScheduleFormBloc(
      loadPreparationByScheduleIdUseCase,
      getPreparationByScheduleIdUseCase,
      getDefaultPreparationUseCase,
      getScheduleByIdUseCase,
      createScheduleWithPlaceUseCase,
      createCustomPreparationUseCase,
      updateScheduleUseCase,
      updatePreparationByScheduleIdUseCase,
      authBloc,
    );
  }

  Future<void> primeEditState(ScheduleFormBloc bloc) async {
    final loaded = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormEditRequested(scheduleId: 'schedule-1'));
    await loaded;
  }

  Future<void> primeCreateState(ScheduleFormBloc bloc) async {
    final loaded = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormCreateRequested());
    await loaded;
  }

  Future<void> pumpSheet(WidgetTester tester, ScheduleFormBloc bloc) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const Key('open_sheet'),
                onPressed: () {
                  showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => BlocProvider.value(
                      value: bloc,
                      child: ScheduleMultiPageForm(
                        onSaved: () => bloc.add(const ScheduleFormUpdated()),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_sheet')));
    await tester.pumpAndSettle();
  }

  Future<void> pumpScheduleScreen(
    WidgetTester tester, {
    required Widget screen,
  }) async {
    getIt.registerFactoryParam<ScheduleFormBloc, AuthBloc, dynamic>(
      (_, __) => buildBloc(),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goToFinalStepAndSubmit(WidgetTester tester) async {
    Finder nextButton() => find.descendant(
      of: find.byType(TopBar),
      matching: find.byType(TextButton),
    );

    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    await tester.tap(nextButton());
    await tester.pump();
  }

  setUp(() {
    loadPreparationByScheduleIdUseCase = StubLoadPreparationByScheduleIdUseCase(
      (_) async {},
    );
    getPreparationByScheduleIdUseCase = StubGetPreparationByScheduleIdUseCase(
      (_) async => preparation,
    );
    getDefaultPreparationUseCase = StubGetDefaultPreparationUseCase(
      () async => preparation,
    );
    getScheduleByIdUseCase = StubGetScheduleByIdUseCase((_) async => schedule);
    createScheduleWithPlaceUseCase = StubCreateScheduleWithPlaceUseCase(
      (_) async {},
    );
    createCustomPreparationUseCase = StubCreateCustomPreparationUseCase(
      (_, __) async {},
    );
    updateScheduleUseCase = StubUpdateScheduleUseCase((_) async {});
    updatePreparationByScheduleIdUseCase =
        StubUpdatePreparationByScheduleIdUseCase((_, __) async {});

    loadAdjacentScheduleWithPreparationUseCase =
        StubLoadAdjacentScheduleWithPreparationUseCase(
          ({required startDate, required endDate}) async {},
        );

    getAdjacentSchedulesWithPreparationUseCase =
        StubGetAdjacentSchedulesWithPreparationUseCase(
          ({
            required selectedDateTime,
            String? currentScheduleId,
            required startDate,
            required endDate,
          }) async => const AdjacentSchedulesWithPreparationEntity(),
        );

    authBloc = StubAuthBloc(
      AuthState(
        user: UserEntity(
          id: 'user-1',
          email: 'user@test.com',
          name: 'tester',
          spareTime: const Duration(minutes: 5),
          note: '',
          score: 1,
          isOnboardingCompleted: true,
        ),
      ),
    );

    if (getIt.isRegistered<ScheduleDateTimeCubit>()) {
      getIt.unregister<ScheduleDateTimeCubit>();
    }

    getIt
        .registerFactoryParam<ScheduleDateTimeCubit, ScheduleFormBloc, dynamic>(
          (scheduleFormBloc, _) => ScheduleDateTimeCubit(
            scheduleFormBloc,
            loadAdjacentScheduleWithPreparationUseCase,
            getAdjacentSchedulesWithPreparationUseCase,
          ),
        );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
    'final submit does not close sheet immediately while submitting',
    (tester) async {
      final submitCompleter = Completer<void>();
      updateScheduleUseCase.handler = (_) => submitCompleter.future;

      final bloc = buildBloc();
      addTearDown(bloc.close);

      await primeEditState(bloc);
      await pumpSheet(tester, bloc);

      await goToFinalStepAndSubmit(tester);

      expect(find.byType(ScheduleMultiPageForm), findsOneWidget);

      submitCompleter.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('create screen initializes form bloc with selected date', (
    tester,
  ) async {
    await pumpScheduleScreen(
      tester,
      screen: ScheduleCreateScreen(initialDate: DateTime(2027, 3, 21)),
    );

    expect(find.byType(ScheduleMultiPageForm), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit screen initializes form bloc with requested schedule', (
    tester,
  ) async {
    await pumpScheduleScreen(
      tester,
      screen: const ScheduleEditScreen(scheduleId: 'schedule-1'),
    );

    expect(find.byType(ScheduleMultiPageForm), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet closes after successful submit', (tester) async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    await primeEditState(bloc);
    await pumpSheet(tester, bloc);

    await goToFinalStepAndSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleMultiPageForm), findsNothing);
  });

  testWidgets('sheet stays open and shows error when submit fails', (
    tester,
  ) async {
    updateScheduleUseCase.handler = (_) => Future.error(Exception('update'));

    final bloc = buildBloc();
    addTearDown(bloc.close);

    await primeEditState(bloc);
    await pumpSheet(tester, bloc);

    await goToFinalStepAndSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleMultiPageForm), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('edited name and place are submitted from form steps', (
    tester,
  ) async {
    ScheduleEntity? updatedSchedule;
    updateScheduleUseCase.handler = (schedule) async {
      updatedSchedule = schedule;
    };

    final bloc = buildBloc();
    addTearDown(bloc.close);

    await primeEditState(bloc);
    await pumpSheet(tester, bloc);

    Finder nextButton() => find.descendant(
      of: find.byType(TopBar),
      matching: find.byType(TextButton),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Edited Meeting');
    await tester.pump();
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'New Office');
    await tester.pump();
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    expect(updatedSchedule, isNotNull);
    expect(updatedSchedule!.scheduleName, 'Edited Meeting');
    expect(updatedSchedule!.place.placeName, 'New Office');
  });

  testWidgets('date time overlap keeps next disabled', (tester) async {
    getAdjacentSchedulesWithPreparationUseCase =
        StubGetAdjacentSchedulesWithPreparationUseCase(
          ({
            required selectedDateTime,
            String? currentScheduleId,
            required startDate,
            required endDate,
          }) async => AdjacentSchedulesWithPreparationEntity(
            nextSchedule: ScheduleWithPreparationEntity(
              id: 'schedule-2',
              place: const PlaceEntity(id: 'place-2', placeName: 'Next Office'),
              scheduleName: 'Next Meeting',
              scheduleTime: DateTime(2027, 3, 20, 9, 20),
              moveTime: const Duration(minutes: 10),
              isChanged: false,
              isStarted: false,
              scheduleSpareTime: Duration.zero,
              scheduleNote: '',
              preparation: PreparationWithTimeEntity.fromPreparation(
                preparation,
              ),
            ),
          ),
        );

    final bloc = buildBloc();
    addTearDown(bloc.close);

    await primeEditState(bloc);
    await pumpSheet(tester, bloc);

    Finder nextButton() => find.descendant(
      of: find.byType(TopBar),
      matching: find.byType(TextButton),
    );

    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    final button = tester.widget<TextButton>(nextButton());
    expect(button.onPressed, isNull);
  });

  testWidgets('cancelling date and time pickers keeps next disabled', (
    tester,
  ) async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    await primeCreateState(bloc);
    await pumpSheet(tester, bloc);

    Finder nextButton() => find.descendant(
      of: find.byType(TopBar),
      matching: find.byType(TextButton),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Meeting');
    await tester.pump();
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel'));
      await tester.pumpAndSettle();
    }

    final button = tester.widget<TextButton>(nextButton());
    expect(button.onPressed, isNull);
  });
}
