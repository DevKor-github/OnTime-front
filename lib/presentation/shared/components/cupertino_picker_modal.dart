import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';

extension ModalBottomSheetExtension on BuildContext {
  void showCupertinoTimerPickerModal({
    required String title,
    required Duration initialValue,
    required CupertinoTimerPickerMode mode,
    required Function(Duration value) onSaved,
    VoidCallback? onDisposed,
  }) {
    var duration = initialValue;
    _showPicker(
      title: title,
      onSaved: () => onSaved(duration),
      onDisposed: onDisposed,
      picker: CupertinoTimerPicker(
        mode: mode,
        initialTimerDuration: initialValue,
        itemExtent: 32,
        onTimerDurationChanged: (value) => duration = value,
      ),
    );
  }

  void showCupertinoMinutePickerModal({
    required String title,
    required Duration initialValue,
    required Function(Duration value) onSaved,
    VoidCallback? onDisposed,
  }) {
    var minutes = initialValue.inMinutes;
    final controller = FixedExtentScrollController(initialItem: minutes);
    _showPicker(
      title: title,
      onSaved: () => onSaved(Duration(minutes: minutes)),
      onDisposed: () {
        controller.dispose();
        onDisposed?.call();
      },
      picker: SizedBox(
        width: 69,
        child: CupertinoPicker(
          scrollController: controller,
          looping: true,
          itemExtent: 32,
          onSelectedItemChanged: (value) => minutes = value,
          children: List.generate(
            60,
            (index) => Text(index.toString().padLeft(2, '0')),
          ),
        ),
      ),
    );
  }

  void showCupertinoDatePickerModal({
    required String title,
    required DateTime initialValue,
    required Function(DateTime value) onSaved,
    required CupertinoDatePickerMode mode,
    VoidCallback? onDisposed,
  }) {
    var dateTime = initialValue;
    _showPicker(
      title: title,
      onSaved: () => onSaved(dateTime),
      onDisposed: onDisposed,
      picker: CupertinoDatePicker(
        mode: mode,
        initialDateTime: initialValue,
        itemExtent: 32,
        onDateTimeChanged: (value) => dateTime = value,
      ),
    );
  }

  void _showPicker({
    required String title,
    required Widget picker,
    required VoidCallback onSaved,
    VoidCallback? onDisposed,
  }) {
    showModalBottomSheet<void>(
      context: this,
      isScrollControlled: true,
      barrierColor: const Color(0x6b000000),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _PickerSheet(
        title: title,
        picker: picker,
        onSaved: () {
          Navigator.pop(context);
          onSaved();
        },
      ),
    ).whenComplete(() => onDisposed?.call());
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.picker,
    required this.onSaved,
  });
  final String title;
  final Widget picker;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: const Color(0xff4f69df),
          primaryContainer: const Color(0xffdce3ff),
          onPrimaryContainer: const Color(0xff23346b),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, bottom < 21 ? 21 : bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(height: 167, child: Center(child: picker)),
              const SizedBox(height: 24),
              Row(
                children: [
                  ModalWideButton(
                    layout: ModalWideButtonLayout.flex,
                    text: l10n.cancel,
                    variant: ModalWideButtonVariant.subtle,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                  ModalWideButton(
                    layout: ModalWideButtonLayout.flex,
                    text: l10n.localeName.startsWith('ko') ? '입력' : l10n.ok,
                    variant: ModalWideButtonVariant.primary,
                    onPressed: onSaved,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
