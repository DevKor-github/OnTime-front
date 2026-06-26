import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/schedule_create/components/keyboard_backed_bottom_sheet.dart';

void main() {
  testWidgets('paints a white backplate behind the iOS keyboard inset', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      const MaterialApp(
        home: KeyboardBackedBottomSheet(child: SizedBox.expand()),
      ),
    );

    final backplate = find.byKey(
      KeyboardBackedBottomSheet.keyboardBackplateKey,
    );

    expect(backplate, findsOneWidget);
    expect(tester.widget<ColoredBox>(backplate).color, Colors.white);
    expect(tester.getSize(backplate).height, 344);
  });

  testWidgets('does not add keyboard backplate while keyboard is hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KeyboardBackedBottomSheet(child: SizedBox.expand()),
      ),
    );

    expect(
      find.byKey(KeyboardBackedBottomSheet.keyboardBackplateKey),
      findsNothing,
    );
  });
}
