import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/onboard_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/cubit/preparation_time_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/screens/preparation_time_form.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_screen.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_start_screen.dart';
import 'package:on_time_front/presentation/shared/components/check_button.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeOnboardUseCase useCase;
  late OnboardingCubit onboardingCubit;

  setUp(() async {
    await getIt.reset();
    useCase = _FakeOnboardUseCase();
    onboardingCubit = OnboardingCubit(useCase);
    getIt.registerSingleton<OnboardingCubit>(onboardingCubit);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('start screen enters the entirely local onboarding flow', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/onboardingStart',
      routes: [
        GoRoute(
          path: '/onboardingStart',
          builder: (_, _) => const OnboardingStartScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Scaffold(body: Text('local onboarding')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Start'));
    await tester.pumpAndSettle();

    expect(find.text('local onboarding'), findsOneWidget);
  });

  testWidgets(
    'selected preparation and timing are submitted as the Local Profile setup',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (_, _) => const OnboardingScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      expect(
        find.text('Please select your usual preparation process.'),
        findsOneWidget,
      );
      expect(_nextButton(tester).onPressed, isNull);

      await tester.tap(find.byType(CheckButton).first);
      await tester.pump();
      expect(_nextButton(tester).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.textContaining('order'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();
      expect(
        find.text('Please tell us the time required for each step.'),
        findsOneWidget,
      );
      expect(_nextButton(tester).onPressed, isNull);

      final timeContext = tester.element(find.byType(PreparationTimeForm));
      timeContext.read<PreparationTimeCubit>().preparationTimeChanged(
        0,
        const Duration(minutes: 10),
      );
      await tester.pump();
      expect(_nextButton(tester).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.text('Set your spare time'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      expect(useCase.submissions, hasLength(1));
      final submission = useCase.submissions.single;
      expect(submission.spareTime, const Duration(minutes: 30));
      expect(submission.preparation.preparationStepList, hasLength(1));
      expect(
        submission.preparation.preparationStepList.single.preparationTime,
        const Duration(minutes: 10),
      );
    },
  );

  testWidgets(
    'failed local profile creation keeps the form and reports error',
    (tester) async {
      useCase.error = StateError('local database unavailable');
      onboardingCubit.onboardingFormChanged(
        preparationStepList: const [
          OnboardingPreparationStepState(
            id: 'step-1',
            preparationName: 'Pack',
            preparationTime: Duration(minutes: 5),
          ),
        ],
        spareTime: const Duration(minutes: 20),
      );
      onboardingCubit.onboardingFormValidated(isValid: true);
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (_, _) => const OnboardingScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      for (var index = 0; index < 3; index += 1) {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsOneWidget);
      expect(useCase.submissions, hasLength(1));
      expect(find.byType(OnboardingScreen), findsOneWidget);
    },
  );
}

MaterialApp _app(GoRouter router) => MaterialApp.router(
  theme: themeData,
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);

ElevatedButton _nextButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next'));

class _OnboardingSubmission {
  const _OnboardingSubmission({
    required this.preparation,
    required this.spareTime,
    required this.note,
  });

  final PreparationEntity preparation;
  final Duration spareTime;
  final String note;
}

class _FakeOnboardUseCase extends OnboardUseCase {
  _FakeOnboardUseCase()
    : super(_FakePreparationRepository(), _FakeUserRepository());

  final submissions = <_OnboardingSubmission>[];
  Object? error;

  @override
  Future<void> call({
    required PreparationEntity preparationEntity,
    required Duration spareTime,
    required String note,
  }) async {
    submissions.add(
      _OnboardingSubmission(
        preparation: preparationEntity,
        spareTime: spareTime,
        note: note,
      ),
    );
    if (error case final value?) throw value;
  }
}

class _FakePreparationRepository implements PreparationRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRepository implements UserRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
