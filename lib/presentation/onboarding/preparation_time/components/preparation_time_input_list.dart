import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/cubit/preparation_time_cubit.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

class PreparationTimeInputFieldList extends StatefulWidget {
  const PreparationTimeInputFieldList({
    super.key,
    required this.preparationTimeList,
    required this.onPreparationTimeChanged,
  });

  final List<PreparationStepTimeState> preparationTimeList;
  final Function(int index, Duration value) onPreparationTimeChanged;

  @override
  State<PreparationTimeInputFieldList> createState() =>
      _PreparationTimeInputFieldListState();
}

class _PreparationTimeInputFieldListState
    extends State<PreparationTimeInputFieldList> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ListView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: widget.preparationTimeList.length,
        itemBuilder: (context, index) {
          final value = widget.preparationTimeList[index];
          return Tile(
            style: TileStyle(
                margin: EdgeInsets.only(bottom: 8),
                backgroundColor: Color(0xFFE6E9F9)),
            trailing: Row(
              children: [
                GestureDetector(
                  child: Text(
                      (value.preparationTime.value.inMinutes < 10 ? '0' : '') +
                          value.preparationTime.value.inMinutes.toString()),
                  onTap: () {
                    context.showCupertinoMinutePickerModal(
                      title: '시간을 선택해주세요',
                      initialValue: value.preparationTime.value,
                      onSaved: (value) {
                        widget.onPreparationTimeChanged(index, value);
                      },
                    );
                  },
                ),
                SizedBox(width: 35),
                Text('분'),
              ],
            ),
            child: Text(value.preparationName),
          );
        },
      ),
    );
  }
}
