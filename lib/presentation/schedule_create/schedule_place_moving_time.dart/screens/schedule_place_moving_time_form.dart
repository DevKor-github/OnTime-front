import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time.dart/cubit/schedule_place_moving_time_cubit.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';
import 'package:on_time_front/presentation/schedule_create/components/message_bubble.dart';

class SchedulePlaceMovingTimeForm extends StatefulWidget {
  const SchedulePlaceMovingTimeForm({super.key});

  @override
  State<SchedulePlaceMovingTimeForm> createState() =>
      _SchedulePlaceMovingTimeFormState();
}

class _SchedulePlaceMovingTimeFormState
    extends State<SchedulePlaceMovingTimeForm> {
  final FocusNode _placeFocusNode = FocusNode();
  final FocusNode _timeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _placeFocusNode.dispose();
    _timeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SchedulePlaceMovingTimeCubit,
        SchedulePlaceMovingTimeState>(builder: (context, state) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.appointmentPlace,
            ),
            initialValue: state.placeName.value,
            focusNode: _placeFocusNode,
            textInputAction: TextInputAction.next,
            onChanged: (newValue) {
              context
                  .read<SchedulePlaceMovingTimeCubit>()
                  .placeNameChanged(newValue);
            },
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.travelTime),
                  focusNode: _timeFocusNode,
                  textInputAction: TextInputAction.done,
                  controller: TextEditingController(
                      text:
                          '${state.moveTime.value.inHours}${AppLocalizations.of(context)!.hours} ${state.moveTime.value.inMinutes % 60}${AppLocalizations.of(context)!.minutes}'),
                  onTap: () {
                    context.showCupertinoTimerPickerModal(
                        title: AppLocalizations.of(context)!.selectTime,
                        mode: CupertinoTimerPickerMode.hm,
                        initialValue: state.moveTime.value,
                        onSaved: (Duration newTime) {
                          context
                              .read<SchedulePlaceMovingTimeCubit>()
                              .moveTimeChanged(newTime);
                        },
                        onDisposed: () {});
                  },
                ),
              ),
            ],
          ),
          if (state.hasOverlapMessage)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0),
              child: MessageBubble(
                      message: state.getOverlapMessage(context)!,
                type: state.isOverlapError
                    ? MessageBubbleType.error
                    : MessageBubbleType.warning,
                    ),
            ),
        ],
      );
    });
  }
}
