import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_reset_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/shared/components/app_spinner.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/presentation/startup/screens/local_data_recovery_screen.dart';

import '../../helpers/visual_test_fonts.dart';

class _AuthBlocStub extends Fake implements AuthBloc {
  int retryCount = 0;

  @override
  AuthState get state => const AuthState.recovery();

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  void add(AuthEvent event) => retryCount++;
}

class _ResetServiceStub extends Fake implements LocalDataResetService {
  Completer<void>? pending;

  @override
  Future<void> reset() => pending?.future ?? Future<void>.value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualTestFonts);

  late _AuthBlocStub authBloc;
  late _ResetServiceStub resetService;
  setUp(() async {
    await getIt.reset();
    authBloc = _AuthBlocStub();
    resetService = _ResetServiceStub();
    getIt.registerSingleton<LocalDataResetService>(resetService);
  });
  tearDown(() async => getIt.reset());

  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        debugShowCheckedModeBanner: false,
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const LocalDataRecoveryScreen(),
        ),
      ),
    );
  }

  testWidgets('recovery default visual remains reviewed', (tester) async {
    await pumpScreen(tester, const Size(390, 844));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('../../goldens/goldens/recovery_default_390x844.png'),
    );
  });

  testWidgets('recovery retry stays available without deleting data', (
    tester,
  ) async {
    await pumpScreen(tester, const Size(375, 667));
    await tester.tap(find.text('다시 시도'));
    expect(authBloc.retryCount, 1);
    expect(find.text('모든 로컬 데이터 초기화'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovery reset asks for confirmation in the Figma dialog', (
    tester,
  ) async {
    await pumpScreen(tester, const Size(390, 844));
    await tester.tap(find.text('모든 로컬 데이터 초기화'));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .width,
      277,
    );
    expect(find.text('복구하지 않고 삭제할까요?'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/goldens/recovery_reset_confirmation_390x844.png',
      ),
    );
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('recovery busy state keeps actions disabled and spinner placed', (
    tester,
  ) async {
    resetService.pending = Completer<void>();
    await pumpScreen(tester, const Size(390, 844));
    await tester.tap(find.text('모든 로컬 데이터 초기화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모두 삭제'));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(AppSpinner), findsOneWidget);
    expect(tester.getTopLeft(find.byType(AppSpinner)).dy, 585.5);
    expect(tester.getSize(find.byType(AppSpinner)), const Size(40, 40));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(tester.widget<TextButton>(find.byType(TextButton).first).onPressed, isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('../../goldens/goldens/recovery_busy_390x844.png'),
    );

    resetService.pending!.completeError(StateError('reset failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(AppSpinner), findsNothing);
    expect(find.textContaining('초기화하지 못했습니다'), findsOneWidget);
  });
}
