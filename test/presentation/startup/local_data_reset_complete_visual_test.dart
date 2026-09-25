import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

import '../../helpers/visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualTestFonts);

  testWidgets('reset complete default visual remains reviewed', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = FakeViewPadding(top: 44, bottom: 21);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(theme: themeData, home: const LocalDataResetCompleteScreen()),
    );

    expect(find.text('다시 시작 안내'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('../../goldens/goldens/reset_complete_390x844.png'),
    );
  });

  testWidgets('reset complete stays readable at large text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(375, 667),
            textScaler: TextScaler.linear(2),
          ),
          child: LocalDataResetCompleteScreen(),
        ),
      ),
    );

    expect(find.text('로컬 데이터 초기화가\n완료되었습니다'), findsOneWidget);
    expect(find.textContaining('새 로컬 프로필로'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reset completion provides restart guidance without reopening closed storage',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          home: const LocalDataResetCompleteScreen(),
        ),
      );
      await tester.tap(find.text('다시 시작 안내'));
      await tester.pumpAndSettle();
      expect(find.text('OnTime을 다시 열어 주세요'), findsOneWidget);
      expect(find.text('앱을 완전히 종료한 뒤 다시 열면 새 로컬 프로필로 시작합니다.'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('초기화 완료'), findsOneWidget);
    },
  );
}
