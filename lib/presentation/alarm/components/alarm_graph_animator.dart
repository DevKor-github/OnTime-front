import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_graph_component.dart';

class AlarmGraphAnimator extends StatefulWidget {
  final double progress;

  const AlarmGraphAnimator({
    super.key,
    required this.progress,
  });

  @override
  _AlarmGraphAnimatorState createState() => _AlarmGraphAnimatorState();
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

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
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
      begin: previousProgress,
      end: newProgress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward(from: 0);
    previousProgress = newProgress;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(230, 115),
          painter: AlarmGraphComponent(
            progress: _progressAnimation.value,
          ),
        );
      },
    );
  }
}
