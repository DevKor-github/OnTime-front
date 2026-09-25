import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/cubit/preparation_time_cubit.dart';

class PreparationTimeTile extends StatefulWidget {
  const PreparationTimeTile({
    super.key,
    required this.value,
    required this.index,
    required this.onPreparationTimeChanged,
  });

  final PreparationStepTimeState value;
  final int index;
  final void Function(int index, Duration value) onPreparationTimeChanged;

  @override
  State<PreparationTimeTile> createState() => _PreparationTimeTileState();
}

class _PreparationTimeTileState extends State<PreparationTimeTile> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value.preparationTime.value.inMinutes.toString().padLeft(
      2,
      '0',
    ),
  );
  final _focusNode = FocusNode();

  void _focusAndSelect() {
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void didUpdateWidget(covariant PreparationTimeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        oldWidget.value.preparationTime.value !=
            widget.value.preparationTime.value) {
      _controller.text = widget.value.preparationTime.value.inMinutes
          .toString()
          .padLeft(2, '0');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focusAndSelect,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(9999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.value.preparationName,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label:
                    '${widget.value.preparationName} ${l10n.preparationTime} (${l10n.minutes})',
                child: SizedBox(
                  width: Localizations.localeOf(context).languageCode == 'ko'
                      ? (_controller.text.length > 4 ? 108 : 68)
                      : (_controller.text.length > 4 ? 152 : 112),
                  child: TextFormField(
                    key: ValueKey('onboardingMinutes${widget.index}'),
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colors.primaryContainer,
                      suffixText: l10n.minutes,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onTap: _focusAndSelect,
                    onChanged: (text) => widget.onPreparationTimeChanged(
                      widget.index,
                      Duration(minutes: int.tryParse(text) ?? 0),
                    ),
                    onFieldSubmitted: (_) => _focusNode.unfocus(),
                    onTapOutside: (_) => _focusNode.unfocus(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
