import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/cubit/preparation_time_cubit.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/theme/custom_text_theme.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

class PreparationTimeTile extends StatelessWidget {
  const PreparationTimeTile({
    super.key,
    required this.value,
    required this.index,
    required this.onPreparationTimeChanged,
  });

  final PreparationStepTimeState value;
  final int index;

  final Function(int index, Duration value) onPreparationTimeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Tile(
      style: TileStyle(
        margin: EdgeInsets.only(bottom: 8),
        backgroundColor: Color(0xFFE6E9F9),
        padding: EdgeInsets.only(left: 36, right: 40, top: 18, bottom: 18),
      ),
      trailing: Row(
        children: [
          GestureDetector(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.blue.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
                child: Text(
                  (value.preparationTime.value.inMinutes < 10 ? '0' : '') +
                      (value.preparationTime.value.inMinutes < 0
                          ? '0'
                          : value.preparationTime.value.inMinutes.toString()),
                  style: textTheme.custom.titleSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            onTap: () {
              context.showCupertinoMinutePickerModal(
                title: '시간을 선택해주세요',
                initialValue: value.preparationTime.value,
                onSaved: (value) {
                  onPreparationTimeChanged(index, value);
                },
              );
            },
          ),
          SizedBox(width: 10),
          Text(
            '분',
            style: textTheme.custom.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
      child: Text(
        value.preparationName,
        style: textTheme.custom.bodyLarge?.copyWith(
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
