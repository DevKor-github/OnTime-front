import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

class PreparationStepWithOriginalIndex {
  PreparationStepWithOriginalIndex({
    required this.preparationStep,
    required this.originalIndex,
  });

  final PreparationStepWithNameAndId preparationStep;
  final int originalIndex;
}

class PreparationReorderableList extends StatelessWidget {
  PreparationReorderableList(
      {super.key,
      required this.preparationOrderingList,
      required this.onReorder});

  final List<PreparationStepWithOriginalIndex> preparationOrderingList;
  final Function(int oldIndex, int newIndex) onReorder;

  final Widget dragIndicatorSvg = SvgPicture.asset(
    'assets/drag_indicator.svg',
    semanticsLabel: 'drag indicator',
    height: 14,
    width: 14,
    fit: BoxFit.contain,
  );

  @override
  Widget build(BuildContext context) {
    Widget proxyDecorator(
        Widget child, int index, Animation<double> animation) {
      return AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          return SizedBox(
            child: child,
          );
        },
        child: child,
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      proxyDecorator: proxyDecorator,
      itemCount: preparationOrderingList.length,
      itemBuilder: (context, index) => Padding(
        key:
            ValueKey<String>(preparationOrderingList[index].preparationStep.id),
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Tile(
          style: TileStyle(
            backgroundColor: Color(0xFFE6E9F9),
          ),
          trailing: ReorderableDragStartListener(
            index: index,
            child: dragIndicatorSvg,
          ),
          child: Text(
            preparationOrderingList[index].preparationStep.preparationName,
          ),
        ),
      ),
      onReorder: onReorder,
    );
  }
}

class PreparationReorderField extends StatefulWidget {
  const PreparationReorderField(
      {super.key,
      required this.formKey,
      required this.initalValue,
      this.onSaved});

  final GlobalKey<FormState> formKey;
  final List<PreparationStepWithOriginalIndex> initalValue;
  final Function(List<PreparationStepWithOriginalIndex>)? onSaved;

  @override
  State<PreparationReorderField> createState() =>
      _PreparationReorderFieldState();
}

class _PreparationReorderFieldState extends State<PreparationReorderField> {
  List<PreparationStepWithOriginalIndex> preparationOrderingList = [];

  @override
  void initState() {
    preparationOrderingList = widget.initalValue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingPageViewLayout(
      title: Text(
        '평소 준비 과정의 순서로\n조정해주세요',
        style: textTheme.titleLarge,
      ),
      form: Form(
        key: widget.formKey,
        child: FormField<List<PreparationStepWithOriginalIndex>>(
          onSaved: (value) {
            widget.onSaved?.call(
              value ?? preparationOrderingList,
            );
          },
          builder: (field) => PreparationReorderableList(
            preparationOrderingList: preparationOrderingList,
            onReorder: (oldIndex, newIndex) {
              field.didChange(preparationOrderingList);
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final PreparationStepWithOriginalIndex item =
                    preparationOrderingList.removeAt(oldIndex);
                preparationOrderingList.insert(newIndex, item);
              });
            },
          ),
        ),
      ),
    );
  }
}
