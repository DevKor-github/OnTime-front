import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/login/screens/sign_in_main_screen.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets(
    'social sign-in buttons stay visible and ignore taps while session is pending',
    (tester) async {
      final signInCompleter = Completer<void>();
      var signInAttempts = 0;

      await _pumpSubject(
        tester,
        onGoogleSignIn: () {
          signInAttempts += 1;
          return signInCompleter.future;
        },
      );

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      expect(signInAttempts, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Sign in with Google'), findsOneWidget);
      final googleButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(
        googleButton.style?.backgroundColor?.resolve({WidgetState.disabled}),
        Colors.white,
      );
      expect(
        googleButton.style?.foregroundColor?.resolve({WidgetState.disabled}),
        Colors.black,
      );
    },
  );

  testWidgets('failed social sign-in restores buttons and shows error dialog', (
    tester,
  ) async {
    await _pumpSubject(
      tester,
      onGoogleSignIn: () async => throw Exception('backend failed'),
    );

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(find.text('로그인에 실패했어요'), findsOneWidget);
    expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(
      tester.widget<ModalWideButton>(find.byType(ModalWideButton)).variant,
      ModalWideButtonVariant.destructive,
    );
  });

  testWidgets(
    'canceled social sign-in restores buttons without showing error dialog',
    (tester) async {
      await _pumpSubject(
        tester,
        onGoogleSignIn: () async => throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        ),
      );

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.text('로그인에 실패했어요'), findsNothing);
      expect(find.text('Sign in with Google'), findsOneWidget);
    },
  );
}

Future<void> _pumpSubject(
  WidgetTester tester, {
  Future<void> Function()? onGoogleSignIn,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData,
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SignInMainScreen(onGoogleSignIn: onGoogleSignIn),
    ),
  );
}
