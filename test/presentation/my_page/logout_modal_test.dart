import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/my_page/my_page_modal/logout_modal.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('confirming logout dispatches sign-out event', (tester) async {
    final authBloc = _RecordingAuthBloc();

    await _pumpSubject(tester, authBloc);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Do you want to log out?'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(authBloc.events, [const AuthSignOutPressed()]);
  });

  testWidgets('canceling logout keeps auth bloc untouched', (tester) async {
    final authBloc = _RecordingAuthBloc();

    await _pumpSubject(tester, authBloc);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(authBloc.events, isEmpty);
    expect(find.text('Do you want to log out?'), findsNothing);
  });
}

Future<void> _pumpSubject(WidgetTester tester, AuthBloc authBloc) async {
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp(
        theme: themeData,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showLogoutModal(context),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _RecordingAuthBloc extends Mock implements AuthBloc {
  final events = <AuthEvent>[];

  @override
  AuthState get state => AuthState(
    user: const UserEntity(
      id: 'user-1',
      email: 'user@example.com',
      name: 'User',
      spareTime: Duration(minutes: 10),
      note: '',
      score: 4,
      isOnboardingCompleted: true,
    ),
  );

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  void add(AuthEvent event) {
    events.add(event);
  }
}
