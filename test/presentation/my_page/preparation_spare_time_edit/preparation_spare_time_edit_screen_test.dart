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
    expect(find.byType(SnackBar), findsOneWidget);
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
  @override
  Future<void> call() async {}
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
