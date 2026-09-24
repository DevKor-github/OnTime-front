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
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(theme: themeData, home: const LocalDataResetCompleteScreen()),
    );

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
}
