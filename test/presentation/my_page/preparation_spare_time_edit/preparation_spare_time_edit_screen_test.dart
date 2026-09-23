import 'dart:async';

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
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

import '../../../helpers/visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualTestFonts);

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

  testWidgets('save failure keeps editor open and shows error', (tester) async {
    preparationStore.updateDefaultHandler = (_) async {
      throw Exception('save failed');
    };

    await _pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(find.byType(PreparationSpareTimeEditScreen), findsOneWidget);
    expect(find.byType(TwoActionDialog), findsOneWidget);
    expect(find.textContaining('save failed'), findsOneWidget);
  });

  testWidgets('save waits for completion before navigating back', (
    tester,
  ) async {
    final completer = Completer<void>();
    preparationStore.updateDefaultHandler = (_) => completer.future;

    await _pumpRoutedScreen(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextButton).first);
    await tester.pump();

    expect(find.byType(PreparationSpareTimeEditScreen), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(PreparationSpareTimeEditScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('changed preparation step time is submitted', (tester) async {
    await _pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final context = tester.element(find.byType(TextFormField).first);
    context.read<PreparationFormBloc>().add(
      const PreparationFormPreparationStepTimeChanged(
        index: 0,
        preparationStepTime: Duration(minutes: 15),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(
      preparationStore
          .updatedPreparation!
          .preparationStepList
          .single
          .preparationTime,
      const Duration(minutes: 15),
    );
  });

  testWidgets('six-row preparation editor matches the reviewed design', (
    tester,
  ) async {
    preparationStore.defaultPreparation = const PreparationEntity(
      preparationStepList: [
        PreparationStepEntity(
          id: 'step-1',
          preparationName: '샤워하기',
          preparationTime: Duration(minutes: 20),
          nextPreparationId: 'step-2',
        ),
        PreparationStepEntity(
          id: 'step-2',
          preparationName: '옷 갈아입기',
          preparationTime: Duration(minutes: 5),
          nextPreparationId: 'step-3',
        ),
        PreparationStepEntity(
          id: 'step-3',
          preparationName: '화장하기',
          preparationTime: Duration(minutes: 1),
          nextPreparationId: 'step-4',
        ),
        PreparationStepEntity(
          id: 'step-4',
          preparationName: '헤어 세팅하기',
          preparationTime: Duration(minutes: 1),
          nextPreparationId: 'step-5',
        ),
        PreparationStepEntity(
          id: 'step-5',
          preparationName: '짐 챙기기',
          preparationTime: Duration(minutes: 1),
          nextPreparationId: 'step-6',
        ),
        PreparationStepEntity(
          id: 'step-6',
          preparationName: '신발 신기',
          preparationTime: Duration(minutes: 2),
        ),
      ],
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = FakeViewPadding(top: 44, bottom: 21);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);

    await _pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('총 시간: 30분'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(6));
    expect(tester.getTopLeft(find.text('여유시간 수정')), const Offset(16, 121));
    expect(tester.getTopLeft(find.text('총 시간: 30분')), const Offset(16, 309));
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('step-1'))),
      const Rect.fromLTWH(16, 344, 358, 62),
    );
    expect(tester.getSize(find.byTooltip('준비 과정 추가')), const Size(44, 44));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        '../../../goldens/goldens/preparation_spare_time_edit_390x844.png',
      ),
    );

    await tester.tap(find.byTooltip('준비 과정 추가'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(7));
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
        (state) => state.status == DefaultPreparationSpareTimeStatus.submitted,
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

      final failingStore =
          _FakePreparationStore(preparationStore.defaultPreparation)
            ..updateDefaultHandler = (_) async {
              throw Exception('update failed');
            };
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
    BlocProvider<AuthBloc>.value(
      value: _StubAuthBloc(),
      child: MaterialApp(
        theme: themeData,
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PreparationSpareTimeEditScreen(),
      ),
    ),
  );
}

Future<void> _pumpRoutedScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: _StubAuthBloc(),
      child: MaterialApp(
        theme: themeData,
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PreparationSpareTimeEditScreen(),
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
}

class _FakePreparationStore {
  _FakePreparationStore(this.defaultPreparation);

  PreparationEntity defaultPreparation;
  PreparationEntity? updatedPreparation;
  Duration? updatedSpareTime;
  Future<void> Function(PreparationEntity preparationEntity)?
  updateDefaultHandler;
  int loadUserCount = 0;
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
    final handler = store.updateDefaultHandler;
    if (handler != null) {
      await handler(preparationEntity);
      return;
    }
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
      spareTime: Duration(minutes: 10),
      note: '',
      eligibleOutcomeCount: 0,
      onTimeOutcomeCount: 0,
      isOnboardingCompleted: true,
    ),
  );

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}
