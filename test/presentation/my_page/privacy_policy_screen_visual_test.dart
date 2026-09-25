import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/my_page/privacy_policy_screen.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

import '../../helpers/visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualTestFonts);

  Future<void> pumpScreen(WidgetTester tester, {double textScale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = FakeViewPadding(top: 44, bottom: 21);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            padding: const EdgeInsets.only(top: 44, bottom: 21),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const PrivacyPolicyScreen(),
        ),
      ),
    );
  }

  testWidgets('privacy policy uses the Figma text grid', (tester) async {
    await pumpScreen(tester);
    final content = find.textContaining('OnTime 로컬 전용 개인정보 처리방침');
    expect(tester.getTopLeft(content), const Offset(22, 126));
    expect(
      tester.getTopLeft(find.byKey(const Key('privacySection1'))),
      const Offset(16, 169),
    );
    expect(tester.getSize(find.byKey(const Key('privacySection1'))).width, 358);
    expect(find.text('개인정보 처리방침'), findsOneWidget);
  });

  testWidgets('privacy policy first viewport matches the reviewed design', (
    tester,
  ) async {
    await pumpScreen(tester);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('../../goldens/goldens/privacy_policy_390x844.png'),
    );
  });

  testWidgets('privacy policy remains scrollable at large text', (
    tester,
  ) async {
    await pumpScreen(tester, textScale: 2);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });
}
