import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_list_field.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'editing a saved preparation step reports name changes and save',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final changedNames = <String>[];
      final focusLostNames = <String>[];
      var savedCount = 0;

      await _pumpField(
        tester,
        focusNode: focusNode,
        step: _step(
          name: const PreparationNameInputModel.pure('Shower'),
          time: const PreparationTimeInputModel.pure(Duration(minutes: 10)),
        ),
        onNameChanged: changedNames.add,
        onNameFocusLost: focusLostNames.add,
        onNameSaved: () => savedCount += 1,
      );

      await tester.enterText(find.byType(TextFormField), 'Pack bag');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(changedNames, ['Pack bag']);
      expect(focusLostNames, contains('Pack bag'));
      expect(savedCount, greaterThanOrEqualTo(1));
    },
  );

  testWidgets('adding row delays interaction-ended while time picker is open', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    final endedNames = <String>[];
    final changedTimes = <Duration>[];

    await _pumpField(
      tester,
      focusNode: focusNode,
      isAdding: true,
      step: _step(
        name: const PreparationNameInputModel.pure(''),
        time: const PreparationTimeInputModel.pure(Duration.zero),
      ),
      onInteractionEnded: endedNames.add,
      onPreparationTimeChanged: changedTimes.add,
    );

    await tester.enterText(find.byType(TextFormField), 'Coffee');
    await tester.tap(find.text('00'));
    await tester.pumpAndSettle();
    focusNode.unfocus();
    await tester.pump();

    expect(endedNames, isEmpty);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changedTimes, isNotEmpty);
  });

  testWidgets('validation errors explain invalid name and preparation time', (
    tester,
  ) async {
    await _pumpField(
      tester,
      showValidationErrors: true,
      step: _step(
        name: const PreparationNameInputModel.dirty(''),
        time: const PreparationTimeInputModel.dirty(Duration.zero),
      ),
    );

    expect(find.text('Please enter a preparation name.'), findsOneWidget);
    expect(
      find.text('Set preparation time to at least 1 minute.'),
      findsOneWidget,
    );
  });

  testWidgets('validation reports too-large preparation time', (tester) async {
    await _pumpField(
      tester,
      showValidationErrors: true,
      step: _step(
        name: const PreparationNameInputModel.dirty('Pack bag'),
        time: const PreparationTimeInputModel.dirty(Duration(days: 400)),
      ),
    );

    expect(
      find.textContaining('Preparation time can be up to'),
      findsOneWidget,
    );
  });

  testWidgets(
    'updates focus listener and field value when row identity changes',
    (tester) async {
      final firstFocusNode = FocusNode();
      final secondFocusNode = FocusNode();
      addTearDown(firstFocusNode.dispose);
      addTearDown(secondFocusNode.dispose);
      final endedNames = <String>[];

      await _pumpField(
        tester,
        focusNode: firstFocusNode,
        step: _step(
          id: 'step-1',
          name: const PreparationNameInputModel.pure('Shower'),
          time: const PreparationTimeInputModel.pure(Duration(minutes: 10)),
        ),
        onInteractionEnded: endedNames.add,
      );

      await _pumpField(
        tester,
        focusNode: secondFocusNode,
        isAdding: true,
        step: _step(
          id: 'step-2',
          name: const PreparationNameInputModel.pure('Coffee'),
          time: const PreparationTimeInputModel.pure(Duration(minutes: 5)),
        ),
        onInteractionEnded: endedNames.add,
      );
      await tester.pump();

      secondFocusNode.unfocus();
      await tester.pump();

      expect(find.text('Coffee'), findsOneWidget);
      expect(endedNames, ['Coffee']);
    },
  );

  testWidgets('row without remove callback renders as a plain editable tile', (
    tester,
  ) async {
    var removeCount = 0;

    await _pumpField(
      tester,
      step: _step(
        name: const PreparationNameInputModel.pure('Shower'),
        time: const PreparationTimeInputModel.pure(Duration(minutes: 10)),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Shower and pack');

    expect(removeCount, 0);
    expect(find.text('10'), findsOneWidget);
  });
}

Future<void> _pumpField(
  WidgetTester tester, {
  required PreparationStepFormState step,
  int? index,
  bool canRemove = true,
  bool isAdding = false,
  bool showValidationErrors = false,
  FocusNode? focusNode,
  ValueChanged<String>? onNameChanged,
  ValueChanged<String>? onNameFocusLost,
  ValueChanged<String>? onInteractionEnded,
  ValueChanged<Duration>? onPreparationTimeChanged,
  VoidCallback? onNameSaved,
  VoidCallback? onRemove,
}) async {
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: _SvgAssetBundle(),
      child: MaterialApp(
        theme: themeData,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PreparationFormListField(
              preparationStep: step,
              index: index,
              focusNode: focusNode,
              canRemove: canRemove,
              isAdding: isAdding,
              showValidationErrors: showValidationErrors,
              onNameChanged: onNameChanged,
              onNameFocusLost: onNameFocusLost,
              onInteractionEnded: onInteractionEnded,
              onPreparationTimeChanged: onPreparationTimeChanged,
              onNameSaved: onNameSaved,
              onRemove: onRemove,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PreparationStepFormState _step({
  String id = 'step-1',
  required PreparationNameInputModel name,
  required PreparationTimeInputModel time,
}) {
  return PreparationStepFormState(
    id: id,
    preparationName: name,
    preparationTime: time,
    isValid: name.isValid && time.isValid,
  );
}

class _SvgAssetBundle extends CachingAssetBundle {
  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"></svg>';

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(_svg));
    return ByteData.view(bytes.buffer);
  }
}
