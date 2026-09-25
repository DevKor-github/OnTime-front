import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_graph_component.dart';

class AlarmGraphAnimator extends StatefulWidget {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  const AlarmGraphAnimator({
    super.key,
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  State<AlarmGraphAnimator> createState() => _AlarmGraphAnimatorState();
}

class _AlarmGraphAnimatorState extends State<AlarmGraphAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    previousProgress = widget.progress.clamp(0.0, 1.0);
    _progressAnimation = AlwaysStoppedAnimation(previousProgress);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AlarmGraphAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animateToNewProgress(widget.progress);
    }
  }

  void _animateToNewProgress(double newProgress) {
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: newProgress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward(from: 0);
    previousProgress = newProgress;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size.square(268),
          painter: AlarmGraphComponent(
            progress: _progressAnimation.value,
            backgroundColor: widget.backgroundColor,
            progressColor: widget.progressColor,
          ),
        );
      },
    );
  }
}
