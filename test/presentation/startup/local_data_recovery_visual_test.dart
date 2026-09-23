import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualTestFonts);

  late _AuthBlocStub authBloc;
  setUp(() => authBloc = _AuthBlocStub());

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
}
