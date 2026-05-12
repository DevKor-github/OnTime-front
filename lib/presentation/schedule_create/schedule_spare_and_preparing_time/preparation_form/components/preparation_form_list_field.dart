import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:flutter_swipe_action_cell/core/controller.dart';
import 'package:on_time_front/core/validation/backend_constraints.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
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
    this.onNameFocusLost,
    this.onPreparationTimeChanged,
    this.onPreparationTimeTapped,
    this.onRemove,
    this.onNameSaved,
    this.canRemove = true,
    this.isAdding = false,
    this.showValidationErrors = false,
    this.focusNode,
  });

  final PreparationStepFormState preparationStep;
  final int? index;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<String>? onNameFocusLost;
  final ValueChanged<Duration>? onPreparationTimeChanged;
  final VoidCallback? onPreparationTimeTapped;
  final VoidCallback? onRemove;
  final VoidCallback? onNameSaved;
  final bool canRemove;
  final bool isAdding;
  final bool showValidationErrors;
  final FocusNode? focusNode;

  @override
  State<PreparationFormListField> createState() =>
      _PreparationFormListFieldState();
}

class _PreparationFormListFieldState extends State<PreparationFormListField> {
  late final FocusNode _internalFocusNode;
  final SwipeActionController _swipeActionController = SwipeActionController();
  late String _nameValue;
  bool _hasRequestedInitialFocus = false;
  final dragIndicatorSvg = SvgPicture.asset(
    'drag_indicator.svg',
    package: 'assets',
    semanticsLabel: 'drag indicator',
    height: 18,
    width: 18,
    fit: BoxFit.contain,
  );

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChanged);
    _swipeActionController.dispose();
    _internalFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _nameValue = widget.preparationStep.preparationName.value;
    _effectiveFocusNode.addListener(_handleFocusChanged);
    _requestInitialFocusIfNeeded();
  }

  @override
  void didUpdateWidget(covariant PreparationFormListField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preparationStep.id != widget.preparationStep.id) {
      _nameValue = widget.preparationStep.preparationName.value;
    }
    if (!oldWidget.isAdding && widget.isAdding) {
      _hasRequestedInitialFocus = false;
    }
    _requestInitialFocusIfNeeded();
  }

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  void _requestInitialFocusIfNeeded() {
    if (!widget.isAdding || _hasRequestedInitialFocus) {
      return;
    }
    _hasRequestedInitialFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _effectiveFocusNode.requestFocus();
      }
    });
  }

  void _handleFocusChanged() {
    if (!_effectiveFocusNode.hasFocus) {
      _swipeActionController.closeAllOpenCell();
      widget.onNameFocusLost?.call(_nameValue);
      widget.onNameSaved?.call();
    }
  }

  String? _nameErrorText(BuildContext context) {
    if (!widget.showValidationErrors &&
        widget.preparationStep.preparationName.isPure) {
      return null;
    }

    final error = widget.preparationStep.preparationName.validator(
      widget.preparationStep.preparationName.value,
    );
    return switch (error) {
      PreparationNameValidationError.empty => AppLocalizations.of(
        context,
      )!.preparationNameRequired,
      null => null,
    };
  }

  String? _timeErrorText(BuildContext context) {
    if (!widget.showValidationErrors &&
        widget.preparationStep.preparationTime.isPure) {
      return null;
    }

    final error = widget.preparationStep.preparationTime.validator(
      widget.preparationStep.preparationTime.value,
    );
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      PreparationTimeValidationError.zero ||
      PreparationTimeValidationError.negative =>
        l10n.preparationTimeMinimumError,
      PreparationTimeValidationError.tooLarge =>
        l10n.preparationTimeMaximumError(BackendConstraints.maxMinuteValue),
      null => null,
    };
  }

  Widget _buildTile({
    required BuildContext context,
    required String? nameErrorText,
    required String? timeErrorText,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Tile(
      key: ValueKey<String>(widget.preparationStep.id),
      style: TileStyle(padding: EdgeInsets.fromLTRB(21, 19, 21, 19)),
      leading: widget.index == null
          ? dragIndicatorSvg
          : ReorderableDragStartListener(
              index: widget.index!,
              child: dragIndicatorSvg,
            ),
      trailing: PreparationTimeInput(
        time: widget.preparationStep.preparationTime.value,
        hasError: timeErrorText != null,
        onTap: widget.onPreparationTimeTapped,
        onPreparationTimeChanged: widget.onPreparationTimeChanged,
      ),
      child: Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Container(
            constraints: BoxConstraints(minHeight: 30),
            child: Center(
              child: TextFormField(
                scrollPadding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 56,
                ),
                initialValue: widget.preparationStep.preparationName.value,
                onChanged: (value) {
                  _nameValue = value;
                  widget.onNameChanged?.call(value);
                },
                onFieldSubmitted: (value) {
                  _nameValue = value;
                  widget.onNameFocusLost?.call(value);
                  widget.onNameSaved?.call();
                },
                onTapOutside: (event) {
                  _swipeActionController.closeAllOpenCell();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                decoration: InputDecoration(
                  isDense: true,
                  border: nameErrorText == null
                      ? InputBorder.none
                      : UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: colorScheme.error,
                            width: 1.5,
                          ),
                        ),
                  enabledBorder: nameErrorText == null
                      ? InputBorder.none
                      : UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: colorScheme.error,
                            width: 1.5,
                          ),
                        ),
                  focusedBorder: nameErrorText == null
                      ? InputBorder.none
                      : UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: colorScheme.error,
                            width: 2,
                          ),
                        ),
                  contentPadding: EdgeInsets.all(3.0),
                ),
                style: textTheme.bodyLarge,
                focusNode: _effectiveFocusNode,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeableTile({
    required BuildContext context,
    required String? nameErrorText,
    required String? timeErrorText,
  }) {
    final tile = _buildTile(
      context: context,
      nameErrorText: nameErrorText,
      timeErrorText: timeErrorText,
    );
    if (widget.onRemove == null) {
      return tile;
    }

    return SwipeActionCell(
      key: ValueKey<String>('swipe_${widget.preparationStep.id}'),
      backgroundColor: Colors.transparent,
      controller: _swipeActionController,
      trailingActions: [
        SwipeAction(
          onTap: (controller) {
            if (!widget.canRemove) {
              return;
            }
            widget.onRemove?.call();
          },
          color: Colors.transparent,
          content: _SwipeActionContent(
            icon: const Icon(Icons.delete, color: Colors.white, size: 24),
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final nameErrorText = _nameErrorText(context);
    final timeErrorText = _timeErrorText(context);
    final errorTexts = [?nameErrorText, ?timeErrorText];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSwipeableTile(
            context: context,
            nameErrorText: nameErrorText,
            timeErrorText: timeErrorText,
          ),
          if (errorTexts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(21, 6, 21, 2),
              child: DefaultTextStyle(
                style:
                    textTheme.bodySmall?.copyWith(color: colorScheme.error) ??
                    TextStyle(color: colorScheme.error),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final errorText in errorTexts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(errorText),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SwipeActionContent extends StatelessWidget {
  const _SwipeActionContent({required this.icon, required this.color});

  final Widget icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
      ),
      padding: const EdgeInsets.all(18.0),
      child: icon,
    );
  }
}
