import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_create_list.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets(
    'create list forwards edits, reorder changes, and create request',
    (tester) async {
      final bloc = PreparationFormBloc();
      addTearDown(bloc.close);
      final nameChanges = <({int index, String value})>[];
      var createCount = 0;

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
                body: PreparationFormCreateList(
                  preparationNameState: PreparationFormState(
                    preparationStepList: [_step('step-1', 'Shower', 10)],
                  ),
                  onNameChanged: ({required index, required value}) {
                    nameChanges.add((index: index, value: value));
                  },
                  onCreationRequested: () => createCount += 1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Pack');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(nameChanges, [(index: 0, value: 'Pack')]);
      expect(createCount, 1);
    },
  );
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
