import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/google_auth_credential.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/delete_user_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/my_page/my_page_modal/delete_user_modal.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('opens feedback dialog after confirming delete account', (
    tester,
  ) async {
    final repository = _FakeUserRepository();
    final modal = DeleteUserModal(
      deleteUserUseCase: DeleteUserUseCase(repository),
      userRepository: repository,
    );

    await _pumpDeleteModal(tester, modal: modal);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('정말 탈퇴하시나요?'), findsOneWidget);
    expect(find.textContaining('현재 로그인한 계정의 탈퇴'), findsOneWidget);
    expect(find.text('계속 사용할게요'), findsOneWidget);
    expect(find.text('그래도 탈퇴할게요'), findsOneWidget);

    await tester.tap(find.text('그래도 탈퇴할게요'));
    await tester.pumpAndSettle();

    expect(find.text('더 좋은 서비스로 다시 만나요'), findsOneWidget);
    expect(find.textContaining('계정 탈퇴 요청이 전송됩니다'), findsOneWidget);
    expect(find.text('탈퇴하지 않고 계속 사용하기'), findsOneWidget);
    expect(find.text('의견 보내고 탈퇴하기'), findsOneWidget);
  });

  testWidgets('cancels from the first confirmation dialog', (tester) async {
    var didConfirm = false;
    final repository = _FakeUserRepository();
    final modal = DeleteUserModal(
      deleteUserUseCase: DeleteUserUseCase(repository),
      userRepository: repository,
    );

    await _pumpDeleteModal(
      tester,
      modal: modal,
      onConfirm: () => didConfirm = true,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('계속 사용할게요'));
    await tester.pumpAndSettle();

    expect(find.text('더 좋은 서비스로 다시 만나요'), findsNothing);
    expect(repository.deletedNormalFeedback, isNull);
    expect(didConfirm, isFalse);
  });

  testWidgets('cancels from the feedback dialog without deleting', (
    tester,
  ) async {
    var didConfirm = false;
    final repository = _FakeUserRepository();
    final modal = DeleteUserModal(
      deleteUserUseCase: DeleteUserUseCase(repository),
      userRepository: repository,
    );

    await _pumpDeleteModal(
      tester,
      modal: modal,
      onConfirm: () => didConfirm = true,
    );
    await _openFeedbackDialog(tester);

    await tester.tap(find.text('탈퇴하지 않고 계속 사용하기'));
    await tester.pumpAndSettle();

    expect(repository.deletedNormalFeedback, isNull);
    expect(repository.didSignOut, isFalse);
    expect(didConfirm, isFalse);
    expect(find.text('더 좋은 서비스로 다시 만나요'), findsNothing);
  });

  testWidgets('shows loading state while deletion is in progress', (
    tester,
  ) async {
    var didConfirm = false;
    final deleteCompleter = Completer<void>();
    final repository = _FakeUserRepository(deleteCompleter: deleteCompleter);
    final modal = DeleteUserModal(
      deleteUserUseCase: DeleteUserUseCase(repository),
      userRepository: repository,
    );

    await _pumpDeleteModal(
      tester,
      modal: modal,
      onConfirm: () => didConfirm = true,
    );
    await _openFeedbackDialog(tester);

    await tester.enterText(find.byType(TextField), 'Need a reset');
    await tester.tap(find.text('의견 보내고 탈퇴하기'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.deletedNormalFeedback, isNull);

    await tester.tap(find.text('탈퇴하지 않고 계속 사용하기'));
    await tester.pump();
    expect(find.text('더 좋은 서비스로 다시 만나요'), findsOneWidget);

    deleteCompleter.complete();
    await tester.pumpAndSettle();

    expect(repository.deletedNormalFeedback, 'Need a reset');
    expect(repository.didSignOut, isTrue);
    expect(didConfirm, isTrue);
  });

  testWidgets(
    'keeps feedback dialog open and shows error when deletion fails',
    (tester) async {
      var didConfirm = false;
      final repository = _FakeUserRepository(deleteError: Exception('failed'));
      final modal = DeleteUserModal(
        deleteUserUseCase: DeleteUserUseCase(repository),
        userRepository: repository,
      );

      await _pumpDeleteModal(
        tester,
        modal: modal,
        onConfirm: () => didConfirm = true,
      );
      await _openFeedbackDialog(tester);

      await tester.tap(find.text('의견 보내고 탈퇴하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(TwoActionDialog), findsOneWidget);
      expect(find.text('오류'), findsOneWidget);
      expect(find.text('더 좋은 서비스로 다시 만나요'), findsOneWidget);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.byType(TwoActionDialog), findsNothing);
      expect(find.text('더 좋은 서비스로 다시 만나요'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repository.didSignOut, isFalse);
      expect(didConfirm, isFalse);
    },
  );

  testWidgets('deletes account, signs out, and calls confirm on success', (
    tester,
  ) async {
    var didConfirm = false;
    final repository = _FakeUserRepository();
    final modal = DeleteUserModal(
      deleteUserUseCase: DeleteUserUseCase(repository),
      userRepository: repository,
    );

    await _pumpDeleteModal(
      tester,
      modal: modal,
      onConfirm: () => didConfirm = true,
    );
    await _openFeedbackDialog(tester);

    await tester.enterText(find.byType(TextField), 'No longer needed');
    await tester.tap(find.text('의견 보내고 탈퇴하기'));
    await tester.pumpAndSettle();

    expect(repository.deletedNormalFeedback, 'No longer needed');
    expect(repository.didSignOut, isTrue);
    expect(didConfirm, isTrue);
    expect(find.text('더 좋은 서비스로 다시 만나요'), findsNothing);
  });
}

Future<void> _pumpDeleteModal(
  WidgetTester tester, {
  required DeleteUserModal modal,
  VoidCallback? onConfirm,
}) async {
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
                  await modal.showDeleteUserModal(
                    context,
                    onConfirm: onConfirm ?? () {},
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
}

Future<void> _openFeedbackDialog(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('그래도 탈퇴할게요'));
  await tester.pumpAndSettle();
}

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository({this.deleteCompleter, this.deleteError});

  final Completer<void>? deleteCompleter;
  final Object? deleteError;
  String? deletedNormalFeedback;
  bool didSignOut = false;

  @override
  Stream<UserEntity> get userStream => const Stream.empty();

  @override
  Future<void> deleteAppleUser({String? feedbackMessage}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteGoogleUser({String? feedbackMessage}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteUser({String? feedbackMessage}) async {
    if (deleteError != null) {
      throw deleteError!;
    }
    if (deleteCompleter != null) {
      await deleteCompleter!.future;
    }
    deletedNormalFeedback = feedbackMessage;
  }

  @override
  Future<void> disconnectGoogleSignIn() => throw UnimplementedError();

  @override
  Future<String?> getUserSocialType() async => null;

  @override
  Future<void> getUser() => throw UnimplementedError();

  @override
  Future<void> postFeedback(String message) => throw UnimplementedError();

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithApple({
    required String idToken,
    required String authCode,
    required String fullName,
    String? email,
  }) => throw UnimplementedError();

  @override
  Future<void> signInWithGoogle(GoogleAuthCredential credential) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    didSignOut = true;
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) => throw UnimplementedError();
}
