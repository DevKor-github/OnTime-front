import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/components/two_button_delete_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('renders destructive dialog and returns false on cancel',
      (tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    dialogResult = await showTwoButtonDeleteDialog(
                      context,
                      title: '정말 약속을 삭제할까요?',
                      description: '약속을 삭제하면 다시 되돌릴 수 없어요.',
                      cancelText: '취소',
                      confirmText: '약속 삭제',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('정말 약속을 삭제할까요?'), findsOneWidget);
    expect(find.text('약속을 삭제하면 다시 되돌릴 수 없어요.'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('약속 삭제'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(dialogResult, isFalse);
  });

  testWidgets('returns true on confirm', (tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    dialogResult = await showTwoButtonDeleteDialog(
                      context,
                      title: '정말 약속을 삭제할까요?',
                      description: '약속을 삭제하면 다시 되돌릴 수 없어요.',
                      cancelText: '취소',
                      confirmText: '약속 삭제',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('약속 삭제'));
    await tester.pumpAndSettle();

    expect(dialogResult, isTrue);
  });
}
