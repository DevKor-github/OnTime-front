import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/schedule_create/components/top_bar.dart';

/// The existing OnTime tokens used by the refreshed Figma screen compositions.
class RefreshTheme extends StatelessWidget {
  const RefreshTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: AppColors.blue.shade600,
        error: AppColors.red.shade900,
      ),
    ),
    child: child,
  );
}

class RecurrenceSheet extends StatelessWidget {
  const RecurrenceSheet({
    super.key,
    required this.title,
    required this.children,
    this.action,
    this.onAction,
    this.onBack,
    this.footer,
    this.showBack = true,
    this.spacing = 16,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback? onBack;
  final List<Widget> children;
  final Widget? footer;
  final bool showBack;
  final double spacing;
  @override
  Widget build(BuildContext context) => RefreshTheme(
    child: Builder(
      builder: (context) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: TopBar(
                    title: title,
                    showAction: false,
                    onPreviousPageButtonClicked: showBack
                        ? onBack ?? () => Navigator.of(context).maybePop()
                        : null,
                    onNextPageButtonClicked: null,
                    isNextButtonEnabled: false,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      for (final child in children)
                        Padding(
                          padding: EdgeInsets.only(bottom: spacing),
                          child: child,
                        ),
                    ],
                  ),
                ),
                if (footer != null || action != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child:
                        footer ??
                        ScreenActions(
                          action: action!,
                          onAction: onAction,
                          onBack:
                              onBack ?? () => Navigator.of(context).maybePop(),
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ScreenActions extends StatelessWidget {
  const ScreenActions({
    super.key,
    required this.action,
    required this.onAction,
    this.onBack,
    this.backLabel,
    this.destructive = false,
    this.loading = false,
  });
  final String action;
  final String? backLabel;
  final VoidCallback? onAction;
  final VoidCallback? onBack;
  final bool destructive;
  final bool loading;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: RefreshTheme(
      child: Builder(
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final longLabel = action.length > 12;
            final fontSize = longLabel ? 14.0 : 16.0;
            final textStyle = Theme.of(context).textTheme.titleSmall!.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onPrimary,
            );
            final painter = TextPainter(
              text: TextSpan(text: action, style: textStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final available = onBack == null
                ? constraints.maxWidth
                : (constraints.maxWidth - 8) * (longLabel ? 2 / 3 : .5);
            final stacked = onBack != null && painter.width > available - 16;
            final primary = ModalWideButton(
              text: action,
              onPressed: onAction,
              variant: destructive
                  ? ModalWideButtonVariant.destructive
                  : ModalWideButtonVariant.primary,
              layout: ModalWideButtonLayout.full,
              height: 48,
              isLoading: loading,
              textStyle: textStyle,
            );
            final secondary = ModalWideButton(
              text: backLabel ?? recurrenceText(context, '뒤로', 'Back'),
              onPressed: loading ? null : onBack,
              variant: ModalWideButtonVariant.subtle,
              layout: ModalWideButtonLayout.full,
              height: 48,
            );
            if (stacked) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [secondary, const SizedBox(height: 8), primary],
              );
            }
            return Row(
              children: [
                if (onBack != null) ...[
                  Expanded(child: secondary),
                  const SizedBox(width: 8),
                ],
                Expanded(flex: longLabel ? 2 : 1, child: primary),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class RecurrencePanel extends StatelessWidget {
  const RecurrencePanel({
    super.key,
    required this.child,
    this.highlighted = false,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final bool highlighted;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Material(
    color: highlighted
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class RecurrenceChoice extends StatelessWidget {
  const RecurrenceChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
    this.child,
  });
  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? colors.primaryContainer
            : colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? colors.primary : AppColors.grey.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.grey.shade700),
                        ),
                      ],
                      if (child != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: child,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecurrenceValue extends StatelessWidget {
  const RecurrenceValue({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.icon,
    this.compact = false,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool compact;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 24),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact)
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey.shade700,
                      ),
                    ),
                  if (!compact) const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.chevron_right, size: 20),
              ),
          ],
        ),
      ),
    ),
  );
}
