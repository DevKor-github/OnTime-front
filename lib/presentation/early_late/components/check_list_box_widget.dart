import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/early_late/components/check_list_item_widget.dart';

class CheckListBoxWidget extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;
  final List<String> checkList;
  final List<bool> checkedStates;
  final void Function(int index) onItemToggled;

  const CheckListBoxWidget({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
    required this.checkList,
    required this.checkedStates,
    required this.onItemToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: screenWidth * 0.9,
        height: screenHeight * 0.35,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xffF6F6F6),
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TextSection(),
                const SizedBox(height: 20),
                _ChecklistSection(
                  checkList: checkList,
                  checkedStates: checkedStates,
                  screenHeight: screenHeight,
                  onItemToggled: onItemToggled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '나가기 전에 확인하세요',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _ChecklistSection extends StatelessWidget {
  final List<String> checkList;
  final List<bool> checkedStates;
  final double screenHeight;
  final void Function(int index) onItemToggled;

  const _ChecklistSection({
    required this.checkList,
    required this.checkedStates,
    required this.screenHeight,
    required this.onItemToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        checkList.length,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: screenHeight * 0.01),
          child: ChecklistItemWidget(
            index: index,
            label: checkList[index],
            isChecked: checkedStates[index],
            onToggle: () => onItemToggled(index),
          ),
        ),
      ),
    );
  }
}
