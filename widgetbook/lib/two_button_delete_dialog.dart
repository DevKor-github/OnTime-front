import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/two_button_delete_dialog.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'TwoButtonDeleteDialog',
  type: CustomAlertDialog,
)
Widget twoButtonDeleteDialogUseCase(BuildContext context) {
  final title = context.knobs.string(
    label: 'Title',
    initialValue: '정말 약속을 삭제할까요?',
  );
  final description = context.knobs.string(
    label: 'Description',
    initialValue: '약속을 삭제하면 다시 되돌릴 수 없어요.',
  );
  final cancelText = context.knobs.string(
    label: 'Cancel Text',
    initialValue: '취소',
  );
  final confirmText = context.knobs.string(
    label: 'Confirm Text',
    initialValue: '약속 삭제',
  );
  final barrierDismissible = context.knobs.boolean(
    label: 'Barrier Dismissible',
    initialValue: true,
  );

  return _TwoButtonDeleteDialogPreview(
    title: title,
    description: description,
    cancelText: cancelText,
    confirmText: confirmText,
    barrierDismissible: barrierDismissible,
  );
}

class _TwoButtonDeleteDialogPreview extends StatefulWidget {
  const _TwoButtonDeleteDialogPreview({
    required this.title,
    required this.description,
    required this.cancelText,
    required this.confirmText,
    required this.barrierDismissible,
  });

  final String title;
  final String description;
  final String cancelText;
  final String confirmText;
  final bool barrierDismissible;

  @override
  State<_TwoButtonDeleteDialogPreview> createState() =>
      _TwoButtonDeleteDialogPreviewState();
}

class _TwoButtonDeleteDialogPreviewState
    extends State<_TwoButtonDeleteDialogPreview> {
  bool? _lastResult;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: double.infinity,
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                final result = await showTwoButtonDeleteDialog(
                  context,
                  title: widget.title,
                  description: widget.description,
                  cancelText: widget.cancelText,
                  confirmText: widget.confirmText,
                  barrierDismissible: widget.barrierDismissible,
                );
                if (!mounted) return;
                setState(() {
                  _lastResult = result;
                });
              },
              child: const Text('Open Delete Dialog'),
            ),
            const SizedBox(height: 12),
            Text(
              'Last Result: ${_lastResult?.toString() ?? 'null'}',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
