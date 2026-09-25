import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppSpinner extends StatefulWidget {
  const AppSpinner({
    super.key,
    this.assetPath = 'feedback_spinner.svg',
    this.assetPackage = 'assets',
  });

  final String assetPath;
  final String? assetPackage;

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '작업 중',
    liveRegion: true,
    child: RotationTransition(
      turns: _rotation,
      child: SvgPicture.asset(
        widget.assetPath,
        package: widget.assetPackage,
        width: 40,
        height: 40,
        excludeFromSemantics: true,
      ),
    ),
  );
}
