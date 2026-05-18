import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/cubit/schedule_form_spare_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_edit_draft_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/screens/schedule_spare_and_preparing_time_form.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<PreparationEditDraftCubit>(
      PreparationEditDraftCubit(),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('renders preparation and user default spare time', (
    tester,
  ) async {
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(
        preparation: _preparation(minutes: 12),
        scheduleSpareTime: const Duration(minutes: 8),
      ),
    );
    final cubit = ScheduleFormSpareTimeCubit(scheduleFormBloc: formBloc)
      ..initialize();
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit);

    expect(
      find.text('Please tell us the time required for each step.'),
      findsOneWidget,
    );
    expect(find.text('12 minutes'), findsOneWidget);
    expect(find.text('Spare Time'), findsOneWidget);
    expect(find.text('8 minutes'), findsOneWidget);
  });

  testWidgets('warning overlap message names the previous schedule', (
    tester,
  ) async {
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(
        scheduleTime: DateTime(2026, 5, 15, 9),
        moveTime: const Duration(minutes: 10),
        scheduleSpareTime: const Duration(minutes: 5),
        preparation: _preparation(minutes: 20),
        maxAvailableTime: const Duration(minutes: 40),
        previousScheduleName: 'Previous meeting',
      ),
    );
    final cubit = ScheduleFormSpareTimeCubit(scheduleFormBloc: formBloc)
      ..initialize();
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit);

    expect(find.textContaining('To avoid overlapping'), findsOneWidget);
    expect(find.textContaining('Previous meeting'), findsOneWidget);
  });

  testWidgets('error overlap message names the previous schedule', (
    tester,
  ) async {
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(
        scheduleTime: DateTime(2026, 5, 15, 9),
        moveTime: const Duration(minutes: 10),
        scheduleSpareTime: const Duration(minutes: 5),
        preparation: _preparation(minutes: 20),
        maxAvailableTime: const Duration(minutes: 35),
        previousScheduleName: 'Previous meeting',
      ),
    );
    final cubit = ScheduleFormSpareTimeCubit(scheduleFormBloc: formBloc)
      ..initialize();
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit);

    expect(find.textContaining('Overlapped'), findsOneWidget);
    expect(find.textContaining('Previous meeting'), findsOneWidget);
  });

  testWidgets('saving spare-time picker submits chosen duration', (
    tester,
  ) async {
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(
        scheduleSpareTime: const Duration(minutes: 8),
        preparation: _preparation(minutes: 12),
      ),
    );
    final cubit = ScheduleFormSpareTimeCubit(scheduleFormBloc: formBloc)
      ..initialize();
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit);
    await tester.tap(find.text('8 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(cubit.state.spareTime.value, const Duration(minutes: 8));
    expect(formBloc.addedEvents.whereType<ScheduleFormValidated>(), isNotEmpty);
  });

  testWidgets('preparation edit route updates preparation from draft', (
    tester,
  ) async {
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(
        scheduleSpareTime: const Duration(minutes: 8),
        preparation: _preparation(minutes: 12),
      ),
    );
    final cubit = ScheduleFormSpareTimeCubit(scheduleFormBloc: formBloc)
      ..initialize();
    addTearDown(cubit.close);
    final edited = _preparation(minutes: 20);

    await _pumpForm(
      tester,
      cubit: cubit,
      preparationEditBuilder: (context, state) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () {
              getIt.get<PreparationEditDraftCubit>().setDraft(edited);
              context.pop();
            },
            child: const Text('save preparation'),
          ),
        );
      },
    );

    await tester.tap(find.text('12 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save preparation'));
    await tester.pumpAndSettle();

    expect(cubit.state.preparation, edited);
    expect(cubit.state.totalPreparationTime, const Duration(minutes: 20));
    expect(getIt.get<PreparationEditDraftCubit>().state, isNull);
    expect(
      formBloc.addedEvents
          .whereType<ScheduleFormPreparationChanged>()
          .single
          .preparation,
      edited,
    );
  });
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required ScheduleFormSpareTimeCubit cubit,
  GoRouterWidgetBuilder? preparationEditBuilder,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: BlocProvider<ScheduleFormBloc>.value(
            value: cubit.scheduleFormBloc,
            child: BlocProvider<AuthBloc>.value(
              value: _StubAuthBloc(
                AuthState(
                  user: const UserEntity(
                    id: 'user-1',
                    email: 'user@example.com',
                    name: 'User',
                    spareTime: Duration(minutes: 8),
                    note: '',
                    score: 4.0,
                    isOnboardingCompleted: true,
                  ),
                ),
              ),
              child: BlocProvider<ScheduleFormSpareTimeCubit>.value(
                value: cubit,
                child: const ScheduleSpareAndPreparingTimeForm(),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/preparationEdit',
        builder:
            preparationEditBuilder ??
            (context, state) => const Scaffold(body: Text('edit preparation')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      theme: themeData,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

PreparationEntity _preparation({required int minutes}) {
  return PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'step-$minutes',
        preparationName: 'Prepare',
        preparationTime: Duration(minutes: minutes),
      ),
    ],
  );
}

class _StubAuthBloc extends Mock implements AuthBloc {
  _StubAuthBloc(this._state);

  final AuthState _state;

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

class _FakeScheduleFormBloc implements ScheduleFormBloc {
  _FakeScheduleFormBloc(this._state);

  final ScheduleFormState _state;
  final addedEvents = <ScheduleFormEvent>[];

  @override
  ScheduleFormState get state => _state;

  @override
  Stream<ScheduleFormState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  void add(ScheduleFormEvent event) {
    addedEvents.add(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
