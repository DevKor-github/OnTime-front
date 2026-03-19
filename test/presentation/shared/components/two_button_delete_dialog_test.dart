import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/presentation/shared/components/two_button_delete_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('delete dialog wrapper returns false on cancel', (tester) async {
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

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(dialogResult, isFalse);
  });

  testWidgets('showTwoActionDialog returns primary result', (tester) async {
    DialogActionResult? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    dialogResult = await showTwoActionDialog(
                      context,
                      config: const TwoActionDialogConfig(
                        title: '삭제 확인',
                        description: '삭제할까요?',
                        secondaryAction: DialogActionConfig(
                          label: '취소',
                          variant: ModalWideButtonVariant.neutral,
                        ),
                        primaryAction: DialogActionConfig(
                          label: '삭제',
                          variant: ModalWideButtonVariant.destructive,
                        ),
                      ),
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

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(dialogResult, DialogActionResult.primary);
  });
}
