import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';
import 'package:on_time_front/presentation/shared/components/check_button.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/custom_text_theme.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

class PreparationNameSelectField extends StatefulWidget {
  const PreparationNameSelectField({
    super.key,
    required this.preparationStep,
    this.onNameChanged,
    this.onNameSaved,
    required this.onSelectionChanged,
    this.isAdding = false,
  });

  final PreparationStepNameState preparationStep;
  final ValueChanged<String>? onNameChanged;
  final VoidCallback? onNameSaved;
  final VoidCallback onSelectionChanged;
  final bool isAdding;

  @override
  State<PreparationNameSelectField> createState() =>
      _PreparationNameSelectFieldState();
}

class _PreparationNameSelectFieldState
    extends State<PreparationNameSelectField> {
  final FocusNode focusNode = FocusNode();

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
        key: ValueKey<String>(widget.preparationStep.preparationId),
        style: TileStyle(padding: EdgeInsets.all(16.0)),
        leading: SizedBox(
          width: 30,
          height: 30,
          child: CheckButton(
            isChecked: widget.preparationStep.isSelected,
            onPressed: widget.onSelectionChanged,
          ),
        ),
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
                  style: textTheme.custom.bodyExtraLarge,
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
