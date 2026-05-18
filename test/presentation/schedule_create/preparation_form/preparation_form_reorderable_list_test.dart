import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_reorderable_list.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('reorderable preparation list wires edits to row callbacks', (
    tester,
  ) async {
    final bloc = PreparationFormBloc();
    addTearDown(bloc.close);
    final changedNames = <(int, String)>[];
    final changedTimes = <(int, Duration)>[];
    final reorders = <(int, int)>[];

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _SvgAssetBundle(),
        child: MaterialApp(
          theme: themeData,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: bloc,
            child: Scaffold(
              body: PreparationFormReorderableList(
                preparationStepList: [
                  _step('step-1', 'Shower', 10),
                  _step('step-2', 'Pack', 5),
                ],
                addingStepId: null,
                showValidationErrors: false,
                stepKeyFor: (id) => ValueKey('row-$id'),
                nameFocusNodeFor: (_) => FocusNode(),
                onNameChanged: (index, value) {
                  changedNames.add((index, value));
                },
                onTimeChanged: (index, value) {
                  changedTimes.add((index, value));
                },
                onReorder: (oldIndex, newIndex) {
                  reorders.add((oldIndex, newIndex));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Morning shower');
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changedNames, [(0, 'Morning shower')]);
    expect(changedTimes, isNotEmpty);
    expect(find.byKey(const ValueKey('row-step-1')), findsOneWidget);
    expect(reorders, isEmpty);
  });
}

PreparationStepFormState _step(String id, String name, int minutes) {
  return PreparationStepFormState(
    id: id,
    preparationName: PreparationNameInputModel.pure(name),
    preparationTime: PreparationTimeInputModel.pure(Duration(minutes: minutes)),
    isValid: true,
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
