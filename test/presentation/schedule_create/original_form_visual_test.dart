import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/keyboard_backed_bottom_sheet.dart';
import 'package:on_time_front/presentation/schedule_create/components/schedule_multi_page_form.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_edit_draft_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/screens/preparation_edit_form.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import '../../helpers/visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualTestFonts);
  setUp(() => getIt.reset());
  tearDown(() => getIt.reset());

  Future<void> prepareViewport(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = FakeViewPadding(top: 44, bottom: 21);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
  }

  for (final state in ['name', 'place']) {
    testWidgets('original $state input uses current production form shell', (
      tester,
    ) async {
      await prepareViewport(tester);
      getIt.registerFactoryParam<ScheduleDateTimeCubit, ScheduleFormBloc, void>(
        (bloc, _) =>
            ScheduleDateTimeCubit(bloc, _LoadAdjacent(), _GetAdjacent()),
      );
      final bloc = _FormBloc(
        ScheduleFormState(
          id: 'form',
          status: ScheduleFormStatus.success,
          isValid: true,
          scheduleName: state == 'name' ? '' : '디자인 리뷰',
          scheduleTime: DateTime(2027, 12, 21, 6),
          moveTime: Duration.zero,
        ),
      );
      await tester.pumpWidget(
        _App(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isDismissible: false,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => BlocProvider<ScheduleFormBloc>.value(
                    value: bloc,
                    child: const KeyboardBackedBottomSheet(
                      child: ScheduleMultiPageForm(),
                    ),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      if (state == 'place') {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/goldens/form_${state}_390x844.png'),
      );
    });
  }

  for (final mode in [
    CupertinoDatePickerMode.date,
    CupertinoDatePickerMode.time,
  ]) {
    testWidgets(
      'native ${mode.name} picker matches source sheet and saves selected value',
      (tester) async {
        await prepareViewport(tester);
        final initial = DateTime(2024, 12, 21, 6);
        DateTime? saved;
        await tester.pumpWidget(
          _App(
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => context.showCupertinoDatePickerModal(
                    title: mode == CupertinoDatePickerMode.date
                        ? '날짜를 입력해주세요'
                        : '시간을 입력해주세요',
                    initialValue: initial,
                    mode: mode,
                    onSaved: (value) => saved = value,
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/goldens/form_${mode.name}_picker_390x844.png',
          ),
        );
        await tester.tap(find.text('입력'));
        await tester.pumpAndSettle();
        expect(saved, initial);
      },
    );
  }

  testWidgets('picker cancel remains reachable at 2x text and does not save', (
    tester,
  ) async {
    await prepareViewport(tester);
    var saved = false;
    await tester.pumpWidget(
      _App(
        scale: 2,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => context.showCupertinoDatePickerModal(
                title: '날짜를 입력해주세요',
                initialValue: DateTime(2024, 12, 21),
                mode: CupertinoDatePickerMode.date,
                onSaved: (_) => saved = true,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('취소'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preparation edit shows computed total and saves the edited draft',
    (tester) async {
      await prepareViewport(tester);
      final draft = PreparationEditDraftCubit()
        ..setDraft(
          const PreparationEntity(
            preparationStepList: [
              PreparationStepEntity(
                id: '1',
                preparationName: '샤워하기',
                preparationTime: Duration(minutes: 10),
                nextPreparationId: '2',
              ),
              PreparationStepEntity(
                id: '2',
                preparationName: '옷 고르기',
                preparationTime: Duration(minutes: 10),
                nextPreparationId: '3',
              ),
              PreparationStepEntity(
                id: '3',
                preparationName: '가방 챙기기',
                preparationTime: Duration(minutes: 5),
                nextPreparationId: '4',
              ),
              PreparationStepEntity(
                id: '4',
                preparationName: '마무리 확인',
                preparationTime: Duration(minutes: 5),
              ),
            ],
          ),
        );
      getIt.registerSingleton<PreparationEditDraftCubit>(draft);
      getIt.registerFactory<PreparationFormBloc>(PreparationFormBloc.new);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/preparationEdit'),
                child: const Text('열기'),
              ),
            ),
          ),
          GoRoute(
            path: '/preparationEdit',
            builder: (_, _) => const PreparationEditForm(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: themeData,
          locale: const Locale('ko'),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('총 시간: 30분'), findsOneWidget);
      expect(find.text('완료'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/goldens/preparation_edit_390x844.png'),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('완료').hitTestable(), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '세수하기');
      await tester.pumpAndSettle();
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();
      expect(draft.state!.preparationStepList.first.preparationName, '세수하기');
      expect(tester.takeException(), isNull);
      await draft.close();
    },
  );
}

class _App extends StatelessWidget {
  const _App({required this.child, this.scale = 1});
  final Widget child;
  final double scale;
  @override
  Widget build(BuildContext context) => MaterialApp(
    // Cupertino's private SF font is unavailable in Flutter's test engine.
    // Use the bundled app font for the native picker glyphs in these captures.
    theme: themeData.copyWith(
      cupertinoOverrideTheme: const CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          pickerTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 21,
            color: Colors.black,
          ),
          dateTimePickerTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 21,
            color: Colors.black,
          ),
        ),
      ),
    ),
    locale: const Locale('ko'),
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  );
}

class _FormBloc implements ScheduleFormBloc {
  _FormBloc(this.state);
  @override
  final ScheduleFormState state;
  @override
  Stream<ScheduleFormState> get stream => const Stream.empty();
  @override
  bool get isClosed => false;
  @override
  void add(ScheduleFormEvent event) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LoadAdjacent implements LoadAdjacentScheduleWithPreparationUseCase {
  @override
  Future<void> call({
    required DateTime startDate,
    required DateTime endDate,
  }) async {}
}

class _GetAdjacent implements GetAdjacentSchedulesWithPreparationUseCase {
  @override
  Future<AdjacentSchedulesWithPreparationEntity> call({
    required DateTime selectedDateTime,
    String? currentScheduleId,
    required DateTime startDate,
    required DateTime endDate,
  }) async => const AdjacentSchedulesWithPreparationEntity();
}
