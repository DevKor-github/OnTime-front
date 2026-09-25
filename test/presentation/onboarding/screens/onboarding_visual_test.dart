import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/onboard_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/onboarding/cubit/onboarding_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/create_icon_button.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/components/preparation_reorderable_list.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/cubit/preparation_order_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/components/preparation_time_tile.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_screen.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_start_screen.dart';
import 'package:on_time_front/presentation/shared/components/check_button.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

import '../../../helpers/visual_test_fonts.dart';

class _OnboardStub extends Fake implements OnboardUseCase {
  PreparationEntity? submitted;
  @override
  Future<void> call({
    required PreparationEntity preparationEntity,
    required Duration spareTime,
    required String note,
  }) async {
    submitted = preparationEntity;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualTestFonts);
  late OnboardingCubit cubit;
  late _OnboardStub useCase;
  setUp(() async {
    await getIt.reset();
    useCase = _OnboardStub();
    cubit = OnboardingCubit(useCase);
    getIt.registerSingleton<OnboardingCubit>(cubit);
  });
  tearDown(() async => getIt.reset());

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = FakeViewPadding(top: 44, bottom: 21);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
    if (screen is OnboardingStartScreen) {
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/design/onboarding_greeting.png'),
          tester.element(find.byType(OnboardingStartScreen)),
        ),
      );
      await tester.pump();
    }
  }

  Future<void> golden(WidgetTester tester, String state) => expectLater(
    find.byType(Scaffold).first,
    matchesGoldenFile(
      '../../../goldens/goldens/onboarding_${state}_390x844.png',
    ),
  );
  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, '다음'));
    await tester.pumpAndSettle();
  }

  void seed(List<String> names, {Duration time = Duration.zero}) {
    cubit.onboardingFormChanged(
      preparationStepList: [
        for (var i = 0; i < names.length; i++)
          OnboardingPreparationStepState(
            id: 'step-$i',
            preparationName: names[i],
            preparationTime: time,
          ),
      ],
      spareTime: const Duration(minutes: 10),
    );
    cubit.onboardingFormValidated(isValid: true);
  }

  testWidgets('welcome uses the source greeting image and 358 by 58 action', (
    tester,
  ) async {
    await pump(tester, const OnboardingStartScreen());
    final button = find.widgetWithText(ElevatedButton, '시작하기');
    expect(tester.getTopLeft(button), const Offset(16, 752));
    expect(tester.getSize(button), const Size(358, 58));
    await golden(tester, 'welcome');
  });

  testWidgets(
    'preparation choices, custom entry, and selected state remain editable',
    (tester) async {
      await pump(tester, const OnboardingScreen());
      expect(find.byType(CheckButton), findsNWidgets(5));
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '다음'))
            .onPressed,
        isNull,
      );
      await golden(tester, 'select');
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(CheckButton).at(i));
        await tester.pump();
      }
      await tester.ensureVisible(find.byType(CreateIconButton));
      await tester.tap(find.byType(CreateIconButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '약 챙기기');
      tester.view.viewInsets = FakeViewPadding(bottom: 270);
      await tester.pumpAndSettle();
      await golden(tester, 'add');
      expect(tester.takeException(), isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, 700),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CheckButton), findsNWidgets(6));
      await golden(tester, 'selected');
    },
  );

  testWidgets(
    'selected preparations can be reordered and persist into timing',
    (tester) async {
      seed(['샤워하기', '메이크업', '옷 고르기/입기', '약 챙기기']);
      await pump(tester, const OnboardingScreen());
      await next(tester);
      await golden(tester, 'order');
      final list = tester.widget<PreparationReorderableList>(
        find.byType(PreparationReorderableList),
      );
      list.onReorder(0, 4);
      await tester.pump();
      final order = tester
          .element(find.byType(PreparationReorderableList))
          .read<PreparationOrderCubit>()
          .state;
      expect(order.preparationStepList.last.preparationName, '샤워하기');
      await next(tester);
      expect(cubit.state.preparationStepList.last.preparationName, '샤워하기');
    },
  );

  testWidgets(
    'numeric duration fields support focus, valid edits and oversized rejection',
    (tester) async {
      seed(['준비과정1', '준비과정2', '준비과정3', '준비과정4']);
      await pump(tester, const OnboardingScreen());
      await next(tester);
      await next(tester);
      expect(find.text('총 시간: 0분', findRichText: true), findsOneWidget);
      await golden(tester, 'time');
      final first = find.byKey(const ValueKey('onboardingMinutes0'));
      final second = find.byKey(const ValueKey('onboardingMinutes1'));
      await tester.tapAt(
        tester.getCenter(find.byType(PreparationTimeTile).first),
      );
      await tester.pump();
      final minutesField = tester.widget<EditableText>(
        find.descendant(of: first, matching: find.byType(EditableText)),
      );
      expect(minutesField.focusNode.hasFocus, isTrue);
      expect(
        minutesField.controller.selection,
        TextSelection(
          baseOffset: 0,
          extentOffset: minutesField.controller.text.length,
        ),
      );
      await tester.enterText(first, '30');
      await tester.enterText(second, '30');
      tester.view.viewInsets = FakeViewPadding(bottom: 282);
      await tester.pumpAndSettle();
      expect(find.text('총 시간: 60분', findRichText: true), findsOneWidget);
      await golden(tester, 'time_focused');
      await tester.enterText(first, '10');
      await tester.pumpAndSettle();
      expect(find.text('총 시간: 40분', findRichText: true), findsOneWidget);
      await golden(tester, 'time_short');
      await tester.enterText(first, '100000');
      await tester.pumpAndSettle();
      await golden(tester, 'time_long');
      expect(cubit.state.isValid, isFalse);
      expect(useCase.submitted, isNull);
      await tester.enterText(first, '10');
      await tester.enterText(
        find.byKey(const ValueKey('onboardingMinutes2')),
        '20',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboardingMinutes3')),
        '15',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(cubit.state.isValid, isTrue);
      await next(tester);
      await golden(tester, 'buffer');
      expect(find.text('10분'), findsOneWidget);
      await next(tester);
      expect(
        useCase.submitted!.preparationStepList.map(
          (e) => e.preparationTime.inMinutes,
        ),
        [10, 30, 20, 15],
      );
    },
  );

  testWidgets('welcome and setup remain usable at 320px with doubled text', (
    tester,
  ) async {
    await pump(
      tester,
      const OnboardingStartScreen(),
      size: const Size(320, 667),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(
      tester,
      const OnboardingScreen(),
      size: const Size(320, 667),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(CheckButton).first);
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '다음'))
          .onPressed,
      isNotNull,
    );
  });
}
