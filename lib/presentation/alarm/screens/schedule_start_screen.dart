import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/utils/duration_format.dart';

enum ScheduleStartPromptVariant {
  defaultPrompt,
  fiveMinutes,
  earlyStart,
}

ScheduleStartPromptVariant scheduleStartPromptVariantFromRouteValue(
  String? value,
) {
  switch (value) {
    case 'fiveMinutes':
      return ScheduleStartPromptVariant.fiveMinutes;
    case 'earlyStart':
      return ScheduleStartPromptVariant.earlyStart;
    default:
      return ScheduleStartPromptVariant.defaultPrompt;
  }
}

class ScheduleStartScreen extends StatefulWidget {
  final ScheduleStartPromptVariant promptVariant;

  @Deprecated(
    'Use promptVariant. This field is kept only for backward compatibility.',
  )
  final bool isFiveMinutesBefore;

  const ScheduleStartScreen({
    super.key,
    this.promptVariant = ScheduleStartPromptVariant.defaultPrompt,
    this.isFiveMinutesBefore = false,
  });

  @override
  State<ScheduleStartScreen> createState() => _ScheduleStartScreenState();
}

class _ScheduleStartScreenState extends State<ScheduleStartScreen> {
  Future<void> _showModal(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await showTwoActionDialog(
      context,
      config: TwoActionDialogConfig(
        title: l10n.confirmLeave,
        description: l10n.confirmLeaveDescription,
        barrierDismissible: false,
        secondaryAction: DialogActionConfig(
          label: l10n.leave,
          variant: ModalWideButtonVariant.neutral,
        ),
        primaryAction: DialogActionConfig(
          label: l10n.stay,
          variant: ModalWideButtonVariant.primary,
        ),
      ),
    );

    if (result == DialogActionResult.secondary && context.mounted) {
      context.go('/home');
    }
  }

  ScheduleStartPromptVariant _resolvedPromptVariant() {
    if (widget.promptVariant != ScheduleStartPromptVariant.defaultPrompt) {
      return widget.promptVariant;
    }
    // ignore: deprecated_member_use_from_same_package
    if (widget.isFiveMinutesBefore) {
      return ScheduleStartPromptVariant.fiveMinutes;
    }
    return ScheduleStartPromptVariant.defaultPrompt;
  }

  String _buildPromptMessage(
    BuildContext context,
    ScheduleStartPromptVariant variant,
    ScheduleWithPreparationEntity? schedule,
  ) {
    switch (variant) {
      case ScheduleStartPromptVariant.fiveMinutes:
        return AppLocalizations.of(context)!.preparationStartsInFiveMinutes;
      case ScheduleStartPromptVariant.earlyStart:
        return _buildEarlyStartPromptMessage(context, schedule);
      case ScheduleStartPromptVariant.defaultPrompt:
        return AppLocalizations.of(context)!.youWillBeLate;
    }
  }

  String _buildEarlyStartPromptMessage(
    BuildContext context,
    ScheduleWithPreparationEntity? schedule,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (schedule == null) {
      return l10n.preparationStartsLaterStartEarly;
    }

    final remainingLeadTime =
        schedule.preparationStartTime.difference(DateTime.now());
    if (remainingLeadTime.inMinutes <= 0) {
      return l10n.preparationStartsLaterStartEarly;
    }

    final formattedLeadTime = formatDuration(context, remainingLeadTime);
    return l10n.preparationStartsEarlyBy(formattedLeadTime);
  }

  void _onPrimaryActionPressed(
    BuildContext context,
    ScheduleStartPromptVariant variant,
  ) {
    if (variant != ScheduleStartPromptVariant.defaultPrompt) {
      context.read<ScheduleBloc>().add(const SchedulePreparationStarted());
    }
    context.go('/alarmScreen');
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = context.watch<ScheduleBloc>().state;
    final promptVariant = _resolvedPromptVariant();
    final isDualActionVariant =
        promptVariant != ScheduleStartPromptVariant.defaultPrompt;
    final schedule = scheduleState.schedule;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final topGap = (h * 0.08).clamp(12.0, 60.0);
            final titleFontSize = (h * 0.055).clamp(22.0, 40.0);
            final placeFontSize = (h * 0.035).clamp(16.0, 25.0);
            final messageFontSize = (h * 0.025).clamp(13.0, 18.0);
            final imageHeight = (h * 0.38).clamp(120.0, 269.0);
            final imageTopGap = (h * 0.06).clamp(10.0, 50.0);
            final bottomGap = (h * 0.04).clamp(12.0, 30.0);

            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      SizedBox(height: topGap),
                      Text(
                        schedule?.scheduleName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff5C79FB),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        schedule?.place.placeName ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: placeFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _buildPromptMessage(context, promptVariant, schedule),
                        style: TextStyle(
                          fontSize: messageFontSize,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey[950]!,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: imageTopGap),
                      Expanded(
                        child: Center(
                          child: SvgPicture.asset(
                            'characters/character.svg',
                            package: 'assets',
                            height: imageHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: bottomGap),
                        child: isDualActionVariant
                            ? _buildTwoButtonLayout(context, promptVariant)
                            : _buildSingleButton(context),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async => _showModal(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSingleButton(BuildContext context) {
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 358),
        child: SizedBox(
          width: double.infinity,
          height: 57,
          child: ElevatedButton(
            onPressed: () async {
              _onPrimaryActionPressed(
                context,
                ScheduleStartPromptVariant.defaultPrompt,
              );
            },
            child: Text(AppLocalizations.of(context)!.startPreparing),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoButtonLayout(
    BuildContext context,
    ScheduleStartPromptVariant variant,
  ) {
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 358),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 57,
              child: ElevatedButton(
                onPressed: () async {
                  _onPrimaryActionPressed(context, variant);
                },
                child: Text(AppLocalizations.of(context)!.startPreparing),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 57,
              child: ElevatedButton(
                onPressed: () async {
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Text(
                  variant == ScheduleStartPromptVariant.fiveMinutes
                      ? AppLocalizations.of(context)!.startInFiveMinutes
                      : AppLocalizations.of(context)!.home,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
