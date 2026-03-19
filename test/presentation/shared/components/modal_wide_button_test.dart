import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('renders destructive fixed button text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: const Scaffold(
          body: Center(
            child: ModalWideButton(
              text: '삭제',
              variant: ModalWideButtonVariant.destructive,
              onPressed: null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('삭제'), findsOneWidget);
  });

  testWidgets('flex layout works in row without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 277,
              child: Row(
                children: const [
                  ModalWideButton(
                    text: '취소',
                    layout: ModalWideButtonLayout.flex,
                    variant: ModalWideButtonVariant.neutral,
                    onPressed: null,
                  ),
                  SizedBox(width: 8),
                  ModalWideButton(
                    text: '삭제',
                    layout: ModalWideButtonLayout.flex,
                    variant: ModalWideButtonVariant.destructive,
                    onPressed: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('취소'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
