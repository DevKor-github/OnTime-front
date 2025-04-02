import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_time_input.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

class PreparationFormListField extends StatefulWidget {
  const PreparationFormListField({
    super.key,
    required this.preparationStep,
    this.index,
    this.onNameChanged,
    this.onPreparationTimeChanged,
    this.onNameSaved,
    this.isAdding = false,
  });

  final PreparationStepFormState preparationStep;
  final int? index;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<Duration>? onPreparationTimeChanged;
  final VoidCallback? onNameSaved;
  final bool isAdding;

  @override
  State<PreparationFormListField> createState() =>
      _PreparationFormListFieldState();
}

class _PreparationFormListFieldState extends State<PreparationFormListField> {
  final FocusNode focusNode = FocusNode();
  final dragIndicatorSvg = SvgPicture.asset(
    'drag_indicator.svg',
    package: 'assets',
    semanticsLabel: 'drag indicator',
    height: 14,
    width: 14,
    fit: BoxFit.contain,
  );

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        widget.onNameSaved?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (widget.isAdding) {
      focusNode.requestFocus();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Tile(
        key: ValueKey<String>(widget.preparationStep.id),
        style: TileStyle(padding: EdgeInsets.all(16.0)),
        leading: widget.index == null
            ? dragIndicatorSvg
            : ReorderableDragStartListener(
                index: widget.index!,
                child: dragIndicatorSvg,
              ),
        trailing: PreparationTimeInput(
            time: widget.preparationStep.preparationTime.value,
            onPreparationTimeChanged: widget.onPreparationTimeChanged),
        child: Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Container(
              constraints: BoxConstraints(minHeight: 30),
              child: Center(
                child: TextFormField(
                  scrollPadding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 56),
                  initialValue: widget.preparationStep.preparationName.value,
                  onChanged: widget.onNameChanged,
                  onFieldSubmitted: (value) => widget.onNameSaved?.call(),
                  onTapOutside: (event) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(3.0),
                  ),
                  style: textTheme.bodyLarge,
                  focusNode: focusNode,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
