import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/two_button_delete_dialog.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/dialog_story_helpers.dart';

@widgetbook.UseCase(
  name: 'Composed Delete Flow',
  type: bool,
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

  return _DeleteDialogPreview(
    title: title,
    description: description,
    cancelText: cancelText,
    confirmText: confirmText,
    barrierDismissible: barrierDismissible,
  );
}

class _DeleteDialogPreview extends StatefulWidget {
  const _DeleteDialogPreview({
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
  State<_DeleteDialogPreview> createState() => _DeleteDialogPreviewState();
}

class _DeleteDialogPreviewState extends State<_DeleteDialogPreview> {
  bool? _lastResult;

  @override
  Widget build(BuildContext context) {
    return DialogStoryBackdrop(
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
          DialogResultText(
            label: 'Last Result: ${_lastResult?.toString() ?? 'null'}',
          ),
        ],
      ),
    );
  }
}
