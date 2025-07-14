import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/components/preparation_time_input_list.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/cubit/preparation_time_cubit.dart';

class PreparationTimeForm extends StatefulWidget {
  const PreparationTimeForm({super.key});

  @override
  State<PreparationTimeForm> createState() => _PreparationTimeFormState();
}

class _PreparationTimeFormState extends State<PreparationTimeForm> {
  @override
  void initState() {
    context.read<PreparationTimeCubit>().initialize();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingPageViewLayout(
      title: AppLocalizations.of(context)!.preparationTimeTitle,
      child: BlocBuilder<PreparationTimeCubit, PreparationTimeState>(
        builder: (context, state) {
          return PreparationTimeInputFieldList(
            preparationTimeList: state.preparationTimeList,
            onPreparationTimeChanged: (index, value) {
              context
                  .read<PreparationTimeCubit>()
                  .preparationTimeChanged(index, value);
            },
          );
        },
      ),
    );
  }
}
