import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/components/preparation_reorderable_list.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/cubit/preparation_order_cubit.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class PreparationOrderForm extends StatefulWidget {
  const PreparationOrderForm({
    super.key,
  });

  @override
  State<PreparationOrderForm> createState() => _PreparationOrderFormState();
}

class _PreparationOrderFormState extends State<PreparationOrderForm> {
  @override
  void initState() {
    context.read<PreparationOrderCubit>().initialize();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingPageViewLayout(
      title: AppLocalizations.of(context)!.preparationOrderTitle,
      child: BlocBuilder<PreparationOrderCubit, PreparationOrderState>(
        builder: (context, state) {
          return PreparationReorderableList(
            preparationOrderingList: state.preparationStepList,
            onReorder: (oldIndex, newIndex) {
              context
                  .read<PreparationOrderCubit>()
                  .preparationOrderChanged(oldIndex, newIndex);
            },
          );
        },
      ),
    );
  }
}
