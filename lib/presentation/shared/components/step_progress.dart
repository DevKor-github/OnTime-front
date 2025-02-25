import 'package:flutter/material.dart';

class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.tabController});

  final TabController tabController;

  Color _getIndicatorColor(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    if (tabController.index >= index) {
      return colorScheme.primary;
    } else {
      return colorScheme.outlineVariant;
    }
  }

  List<Widget> _buildIndicator(BuildContext context, int index) {
    return [
      if (index != 0)
        Flexible(
          child: Container(
            height: 2,
            color: _getIndicatorColor(context, index),
            constraints: BoxConstraints(maxWidth: 57.0, minWidth: 10.0),
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(5.5),
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _getIndicatorColor(context, index),
              width: 1.5,
            ),
            color: index != tabController.index
                ? _getIndicatorColor(context, index)
                : Colors.transparent,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: tabController.length * (57.0 + 11 + 11) - 57.0 + 10.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < tabController.length; i++)
                  ..._buildIndicator(context, i),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < tabController.length; i++)
                Text(
                  'step\n${i + 1}',
                  style: TextStyle(
                    color: _getIndicatorColor(context, i),
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          )
        ],
      ),
    );
  }
}
