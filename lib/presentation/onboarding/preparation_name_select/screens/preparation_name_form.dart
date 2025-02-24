import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/preparation_select_list.dart';
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
    final textTheme = Theme.of(context).textTheme;
    return OnboardingPageViewLayout(
      title: Text(
        '주로 하는 준비 과정을\n선택해주세요',
        style: textTheme.titleLarge,
      ),
      child: PreparationSelectList(),
    );
  }
}
