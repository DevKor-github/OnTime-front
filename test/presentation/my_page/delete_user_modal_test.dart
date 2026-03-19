import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/my_page/my_page_modal/delete_user_modal.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('opens feedback dialog after confirming delete account',
      (tester) async {
    final modal = DeleteUserModal();

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    await modal.showDeleteUserModal(context, onConfirm: () {});
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

    expect(find.text('정말 탈퇴하시나요?'), findsOneWidget);
    expect(find.text('계속 사용할게요'), findsOneWidget);
    expect(find.text('그래도 탈퇴할게요'), findsOneWidget);

    await tester.tap(find.text('그래도 탈퇴할게요'));
    await tester.pumpAndSettle();

    expect(find.text('더 좋은 서비스로 다시 만나요'), findsOneWidget);
    expect(find.text('탈퇴하지 않고 계속 사용하기'), findsOneWidget);
    expect(find.text('의견 보내고 탈퇴하기'), findsOneWidget);
  });
}
