import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/google_authentication_service.dart';
import 'package:on_time_front/domain/entities/google_auth_credential.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/login/screens/sign_in_main_screen.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

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
        onGoogleSignIn: () async =>
            throw const GoogleAuthenticationCanceledException(),
      );

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.text('로그인에 실패했어요'), findsNothing);
      expect(find.text('Sign in with Google'), findsOneWidget);
    },
  );

  testWidgets(
    'default Google sign-in establishes OnTime session with provider credential',
    (tester) async {
      const credential = GoogleAuthCredential(idToken: 'google-id-token');
      final googleAuthenticationService = _FakeGoogleAuthenticationService(
        credential,
      );
      final userRepository = _FakeUserRepository();
      getIt.registerSingleton<GoogleAuthenticationService>(
        googleAuthenticationService,
      );
      getIt.registerSingleton<UserRepository>(userRepository);

      await _pumpSubject(tester);

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(googleAuthenticationService.authenticateCount, 1);
      expect(userRepository.googleCredentials, [credential]);
      expect(find.text('로그인에 실패했어요'), findsNothing);
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

class _FakeGoogleAuthenticationService implements GoogleAuthenticationService {
  _FakeGoogleAuthenticationService(this.credential);

  final GoogleAuthCredential credential;
  int authenticateCount = 0;

  @override
  Stream<GoogleAuthCredential> get authenticationCredentials =>
      const Stream.empty();

  @override
  bool get supportsAuthenticate => true;

  @override
  Future<GoogleAuthCredential> authenticate() async {
    authenticateCount += 1;
    return credential;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> initialize() async {}
}

class _FakeUserRepository implements UserRepository {
  final googleCredentials = <GoogleAuthCredential>[];

  @override
  Stream<UserEntity> get userStream => const Stream.empty();

  @override
  Future<void> signInWithGoogle(GoogleAuthCredential credential) async {
    googleCredentials.add(credential);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
