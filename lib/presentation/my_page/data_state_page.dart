import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';

/// Shared shell for local-data states. System bars are supplied by the OS.
class DataStatePage extends StatelessWidget {
  const DataStatePage({
    super.key,
    required this.title,
    required this.children,
    this.onBack,
    this.showBack = true,
    this.footer,
    this.padding = const EdgeInsets.symmetric(horizontal: 19),
    this.footerPadding = const EdgeInsets.fromLTRB(19, 16, 19, 33),
    this.headerHeight = 44,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget? footer;
  final EdgeInsets padding;
  final EdgeInsets footerPadding;
  final double headerHeight;

  @override
  Widget build(BuildContext context) => RefreshTheme(
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (showBack)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        tooltip: '뒤로',
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                        icon: SvgPicture.asset(
                          'chevron_left.svg',
                          package: 'assets',
                          width: 8,
                          height: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(padding: padding, children: children),
            ),
            if (footer != null) Padding(padding: footerPadding, child: footer),
          ],
        ),
      ),
    ),
  );
}

class DataNotice extends StatelessWidget {
  const DataNotice({
    super.key,
    required this.child,
    this.highlighted = false,
    this.outlinedIcon = false,
    this.padding = const EdgeInsets.all(17),
    this.gap = 15,
    this.minHeight = 0,
  });

  final Widget child;
  final bool highlighted;
  final bool outlinedIcon;
  final EdgeInsets padding;
  final double gap;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: minHeight),
    decoration: BoxDecoration(
      color: highlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(9),
    ),
    padding: padding,
    child: Row(
      crossAxisAlignment: outlinedIcon
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          outlinedIcon
              ? 'assets/design/information_outline.svg'
              : 'assets/design/information_filled.svg',
          width: outlinedIcon ? 23 : 22,
          height: outlinedIcon ? 23 : 22,
          excludeFromSemantics: true,
        ),
        SizedBox(width: gap),
        Expanded(child: child),
      ],
    ),
  );
}
