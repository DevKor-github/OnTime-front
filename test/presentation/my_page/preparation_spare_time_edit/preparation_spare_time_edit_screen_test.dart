import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_user_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_spare_time_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/bloc/default_preparation_spare_time_form_bloc.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/preparation_spare_time_edit_screen.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePreparationStore preparationStore;

  setUp(() async {
    await getIt.reset();
    preparationStore = _FakePreparationStore(
      const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'step-1',
            preparationName: 'Shower',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      ),
    );

    getIt
      ..registerFactory<DefaultPreparationSpareTimeFormBloc>(
        () => DefaultPreparationSpareTimeFormBloc(
          _FakeGetDefaultPreparationUseCase(preparationStore),
          _FakeUpdateDefaultPreparationUseCase(preparationStore),
          _FakeUpdateSpareTimeUseCase(preparationStore),
          _FakeLoadUserUseCase(),
        ),
      )
      ..registerFactory<PreparationFormBloc>(PreparationFormBloc.new);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('keeps preparation edits mounted when spare time changes', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byType(TextFormField).first, 'Coffee');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('15분'), findsOneWidget);
  });

  test(
    'form bloc loads defaults and edits spare time in five-minute steps',
    () async {
      final bloc = _buildBloc(preparationStore);
      addTearDown(bloc.close);

      bloc.add(const FormEditRequested(spareTime: Duration(minutes: 15)));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<DefaultPreparationSpareTimeFormState>().having(
            (state) => state.status,
            'status',
            DefaultPreparationSpareTimeStatus.loading,
          ),
          isA<DefaultPreparationSpareTimeFormState>()
              .having(
                (state) => state.status,
                'status',
                DefaultPreparationSpareTimeStatus.success,
              )
              .having(
                (state) => state.spareTime,
                'spareTime',
                const Duration(minutes: 15),
              ),
        ]),
      );

      bloc
        ..add(const SpareTimeIncreased())
        ..add(const SpareTimeDecreased())
        ..add(const SpareTimeDecreased())
        ..add(const SpareTimeDecreased());
      await testerPumpEventQueue();

      expect(bloc.state.spareTime, const Duration(minutes: 10));
    },
  );

  test(
    'form bloc persists preparation and spare time before reloading user',
    () async {
      final bloc = _buildBloc(preparationStore);
      addTearDown(bloc.close);
      const editedPreparation = PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'step-2',
            preparationName: 'Pack bag',
            preparationTime: Duration(minutes: 8),
          ),
        ],
      );

      bloc.add(const FormEditRequested(spareTime: Duration(minutes: 20)));
      await bloc.stream.firstWhere(
        (state) => state.status == DefaultPreparationSpareTimeStatus.success,
      );
      bloc.add(
        const FormSubmitted(
          note: 'Updated note',
          preparation: editedPreparation,
        ),
      );
      await bloc.stream.firstWhere(
        (state) => state.status == DefaultPreparationSpareTimeStatus.success,
      );

      expect(preparationStore.updatedPreparation, editedPreparation);
      expect(preparationStore.updatedSpareTime, const Duration(minutes: 20));
      expect(preparationStore.loadUserCount, 1);
    },
  );

  test(
    'form bloc reports errors when spare time is absent or update fails',
    () async {
      final missingSpareBloc = _buildBloc(preparationStore);
      addTearDown(missingSpareBloc.close);

      missingSpareBloc.add(
        const FormSubmitted(
          note: '',
          preparation: PreparationEntity(preparationStepList: []),
        ),
      );
      await missingSpareBloc.stream.firstWhere(
        (state) => state.status == DefaultPreparationSpareTimeStatus.error,
      );
      expect(preparationStore.updatedPreparation, isNull);

      final failingStore = _FakePreparationStore(
        preparationStore.defaultPreparation,
      )..failUpdate = true;
      final failingBloc = _buildBloc(failingStore);
      addTearDown(failingBloc.close);

      failingBloc.add(
        const FormEditRequested(spareTime: Duration(minutes: 20)),
      );
      await failingBloc.stream.firstWhere(
        (state) => state.status == DefaultPreparationSpareTimeStatus.success,
      );
      failingBloc.add(
        const FormSubmitted(
          note: '',
          preparation: PreparationEntity(preparationStepList: []),
        ),
      );

      await failingBloc.stream.firstWhere(
        (state) => state.status == DefaultPreparationSpareTimeStatus.error,
      );
    },
  );
}

Future<void> testerPumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

DefaultPreparationSpareTimeFormBloc _buildBloc(_FakePreparationStore store) {
  return DefaultPreparationSpareTimeFormBloc(
    _FakeGetDefaultPreparationUseCase(store),
    _FakeUpdateDefaultPreparationUseCase(store),
    _FakeUpdateSpareTimeUseCase(store),
    _FakeLoadUserUseCase(store),
  );
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData,
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<AuthBloc>.value(
        value: _StubAuthBloc(),
        child: const PreparationSpareTimeEditScreen(),
      ),
    ),
  );
}

class _FakePreparationStore {
  _FakePreparationStore(this.defaultPreparation);

  PreparationEntity defaultPreparation;
  PreparationEntity? updatedPreparation;
  Duration? updatedSpareTime;
  int loadUserCount = 0;
  bool failUpdate = false;
}

class _FakeGetDefaultPreparationUseCase extends Mock
    implements GetDefaultPreparationUseCase {
  _FakeGetDefaultPreparationUseCase(this.store);

  final _FakePreparationStore store;

  @override
  Future<PreparationEntity> call() async => store.defaultPreparation;
}

class _FakeUpdateDefaultPreparationUseCase extends Mock
    implements UpdateDefaultPreparationUseCase {
  _FakeUpdateDefaultPreparationUseCase(this.store);

  final _FakePreparationStore store;

  @override
  Future<void> call(PreparationEntity preparationEntity) async {
    if (store.failUpdate) throw Exception('update failed');
    store.updatedPreparation = preparationEntity;
  }
}

class _FakeUpdateSpareTimeUseCase extends Mock
    implements UpdateSpareTimeUseCase {
  _FakeUpdateSpareTimeUseCase(this.store);

  final _FakePreparationStore store;

  @override
  Future<void> call(Duration newSpareTime) async {
    store.updatedSpareTime = newSpareTime;
  }
}

class _FakeLoadUserUseCase extends Mock implements LoadUserUseCase {
  _FakeLoadUserUseCase([this.store]);

  final _FakePreparationStore? store;

  @override
  Future<void> call() async {
    store?.loadUserCount++;
  }
}

class _StubAuthBloc extends Mock implements AuthBloc {
  @override
  AuthState get state => AuthState(
    user: const UserEntity(
      id: 'user-1',
      email: 'user@example.com',
      name: 'User',
      spareTime: Duration(minutes: 10),
      note: '',
      score: 0,
      isOnboardingCompleted: true,
    ),
  );

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}
