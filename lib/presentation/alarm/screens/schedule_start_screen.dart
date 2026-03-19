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

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Scaffold(
          body: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context
                                    .read<ScheduleBloc>()
                                    .state
                                    .schedule
                                    ?.scheduleName ??
                                '',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff5C79FB),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context
                                    .read<ScheduleBloc>()
                                    .state
                                    .schedule
                                    ?.place
                                    .placeName ??
                                '',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            isFiveMinBefore
                                ? AppLocalizations.of(context)!
                                    .preparationStartsInFiveMinutes
                                : AppLocalizations.of(context)!.youWillBeLate,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey[950]!,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 50),
                            child: SvgPicture.asset(
                              'characters/character.svg',
                              package: 'assets',
                              width: 204,
                              height: 269,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: isFiveMinBefore
                        ? _buildTwoButtonLayout(context)
                        : _buildSingleButton(context),
                  ),
                ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildSingleButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        context.go('/alarmScreen');
      },
      child: Text(AppLocalizations.of(context)!.startPreparing),
    );
  }

  Widget _buildTwoButtonLayout(BuildContext context) {
    return SizedBox(
      width: 358,
      height: 127,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 57,
            child: ElevatedButton(
              onPressed: () async {
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
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(AppLocalizations.of(context)!.startInFiveMinutes),
            ),
          ),
        ],
      ),
    );
  }
}
