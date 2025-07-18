import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/preparation_create_list.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_name/preparation_name_cubit.dart';

class PreparationNameForm extends StatefulWidget {
  const PreparationNameForm({
    super.key,
  });

  @override
  State<PreparationNameForm> createState() => _PreparationNameFormState();
}

class _PreparationNameFormState extends State<PreparationNameForm> {
  @override
  void initState() {
    super.initState();
    context.read<PreparationNameCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingPageViewLayout(
      title: AppLocalizations.of(context)!.preparationNameTitle,
      hint: AppLocalizations.of(context)!.multipleSelection,
      child: BlocBuilder<PreparationNameCubit, PreparationNameState>(
        builder: (context, state) => PreparationCreateList(
          preparationNameState: state,
          onCreationRequested: context
              .read<PreparationNameCubit>()
              .preparationStepCreationRequested,
          onNameChanged:
              context.read<PreparationNameCubit>().preparationStepNameChanged,
          onSelectionChanged: context
              .read<PreparationNameCubit>()
              .preparationStepSelectionChanged,
        ),
      ),
    );
  }
}
