import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/preparation_edit_list.dart';
import 'package:uuid/uuid.dart';

class PreparationEditForm extends StatefulWidget {
  const PreparationEditForm({super.key});

  @override
  State<PreparationEditForm> createState() => _PreparationEditFormState();
}

class _PreparationEditFormState extends State<PreparationEditForm> {
  PreparationFormData preparationFormData =
      PreparationFormData(preparationStepList: []);
  final GlobalKey<FormState> _formKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    preparationFormData = PreparationFormData(preparationStepList: [
      PreparationStepFormData(
        id: Uuid().v7(),
        preparationName: '0',
        preparationTime: Duration(minutes: 30),
      ),
      PreparationStepFormData(
        id: Uuid().v7(),
        preparationName: '1',
      ),
      PreparationStepFormData(
        id: Uuid().v7(),
        preparationName: '2',
      ),
      PreparationStepFormData(
        id: Uuid().v7(),
        preparationName: '3',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            FilledButton(
                onPressed: () {
                  _formKey.currentState?.save();
                },
                child: Text("Save")),
            Expanded(
              child: PreparationEditList(
                formKey: _formKey,
                onSaved: (value) {
                  for (var i in value.preparationStepList) {
                    debugPrint(i.preparationName);
                    debugPrint(i.preparationTime.toString());
                    debugPrint(i.order.toString());
                  }
                },
                preparationList: preparationFormData.preparationStepList,
                onChanged: (value) {
                  setState(() {
                    preparationFormData = preparationFormData.copyWith(
                      preparationStepList: value,
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
