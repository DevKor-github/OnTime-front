import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_step_list_widget.dart';
import 'package:on_time_front/presentation/alarm/utils/preparation_step_state_mapper.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class AlarmScreenBottomSection extends StatelessWidget {
  const AlarmScreenBottomSection({
    super.key,
    required this.preparation,
    required this.onSkip,
    required this.onEndPreparation,
  });

  final PreparationWithTimeEntity preparation;
  final VoidCallback onSkip;
  final VoidCallback onEndPreparation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: ColoredBox(
        color: AppColors.white,
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: AppColors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 13, 12, 0),
                  child: PreparationStepListWidget(
                    preparationSteps: List<PreparationStepEntity>.from(
                      preparation.preparationStepList,
                    ),
                    currentStepIndex: preparation.resolvedCurrentStepIndex,
                    stepElapsedTimes: preparation.stepElapsedTimesInSeconds,
                    preparationStepStates: preparation.preparationStepStates,
                    onSkip: onSkip,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                5,
                16,
                math.max(40, MediaQuery.paddingOf(context).bottom + 12),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onEndPreparation,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(57),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    elevation: 0,
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
                      fontSize: 18,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.finishPreparation),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
