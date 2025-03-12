import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class PreparationTimeInput extends StatelessWidget {
  const PreparationTimeInput(
      {super.key, required this.time, required this.onPreparationTimeChanged});

  final Duration time;
  final ValueChanged<Duration>? onPreparationTimeChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        GestureDetector(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
              child: Text(
                (time.inMinutes < 10 ? '0' : '') +
                    (time.inMinutes < 0 ? '0' : time.inMinutes.toString()),
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          onTap: () {
            context.showCupertinoMinutePickerModal(
              title: '시간을 선택해주세요',
              initialValue: time,
              onSaved: (value) {
                onPreparationTimeChanged?.call(value);
              },
            );
          },
        )
      ],
    );
  }
}
