import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class ScheduleStartScreen extends StatefulWidget {
  final bool isFiveMinutesBefore;

  const ScheduleStartScreen({
    super.key,
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

  bool _isFiveMinutesBefore() {
    return widget.isFiveMinutesBefore;
  }

  @override
  Widget build(BuildContext context) {
    final isFiveMinBefore = _isFiveMinutesBefore();
    final schedule = context.read<ScheduleBloc>().state.schedule;

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
                        isFiveMinBefore
                            ? AppLocalizations.of(context)!
                                .preparationStartsInFiveMinutes
                            : AppLocalizations.of(context)!.youWillBeLate,
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
                        child: isFiveMinBefore
                            ? _buildTwoButtonLayout(context)
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
              context.go('/alarmScreen');
            },
            child: Text(AppLocalizations.of(context)!.startPreparing),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoButtonLayout(BuildContext context) {
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
                  context
                      .read<ScheduleBloc>()
                      .add(const SchedulePreparationStarted());
                  context.go('/alarmScreen');
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
                child: Text(AppLocalizations.of(context)!.startInFiveMinutes),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
