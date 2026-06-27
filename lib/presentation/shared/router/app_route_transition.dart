import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum AppRouteTransition {
  fade,
  standard,
  bottomNavFromLeft,
  bottomNavFromRight,
  scheduleFlow,
}

CustomTransitionPage<T> buildAppRoutePage<T>({
  required LocalKey key,
  required Widget child,
  AppRouteTransition transition = AppRouteTransition.standard,
}) {
  final spec = _AppRouteTransitionSpec.fromTransition(transition);

  return CustomTransitionPage<T>(
    key: key,
    transitionDuration: spec.duration,
    reverseTransitionDuration: spec.reverseDuration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return _AppRouteTransitionView(
        animation: animation,
        transition: transition,
        child: child,
      );
    },
  );
}

class _AppRouteTransitionSpec {
  const _AppRouteTransitionSpec({
    required this.duration,
    required this.reverseDuration,
  });

  final Duration duration;
  final Duration reverseDuration;

  static _AppRouteTransitionSpec fromTransition(AppRouteTransition transition) {
    switch (transition) {
      case AppRouteTransition.fade:
        return const _AppRouteTransitionSpec(
          duration: Duration(milliseconds: 180),
          reverseDuration: Duration(milliseconds: 140),
        );
      case AppRouteTransition.standard:
        return const _AppRouteTransitionSpec(
          duration: Duration(milliseconds: 260),
          reverseDuration: Duration(milliseconds: 220),
        );
      case AppRouteTransition.bottomNavFromLeft:
      case AppRouteTransition.bottomNavFromRight:
        return const _AppRouteTransitionSpec(
          duration: Duration(milliseconds: 220),
          reverseDuration: Duration(milliseconds: 180),
        );
      case AppRouteTransition.scheduleFlow:
        return const _AppRouteTransitionSpec(
          duration: Duration(milliseconds: 200),
          reverseDuration: Duration(milliseconds: 160),
        );
    }
  }
}

class _AppRouteTransitionView extends StatelessWidget {
  const _AppRouteTransitionView({
    required this.animation,
    required this.transition,
    required this.child,
  });

  final Animation<double> animation;
  final AppRouteTransition transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (transition) {
      case AppRouteTransition.fade:
        return FadeTransition(
          opacity: _curvedOpacityAnimation(animation, begin: 0),
          child: child,
        );
      case AppRouteTransition.standard:
        return FadeTransition(
          opacity: _curvedOpacityAnimation(animation, begin: 0.08),
          child: SlideTransition(
            position: _curvedOffsetAnimation(
              animation,
              begin: const Offset(0, 0.032),
            ),
            child: child,
          ),
        );
      case AppRouteTransition.bottomNavFromLeft:
        return FadeTransition(
          opacity: _curvedOpacityAnimation(animation, begin: 0.2),
          child: SlideTransition(
            position: _curvedOffsetAnimation(
              animation,
              begin: const Offset(-0.16, 0),
            ),
            child: child,
          ),
        );
      case AppRouteTransition.bottomNavFromRight:
        return FadeTransition(
          opacity: _curvedOpacityAnimation(animation, begin: 0.2),
          child: SlideTransition(
            position: _curvedOffsetAnimation(
              animation,
              begin: const Offset(0.16, 0),
            ),
            child: child,
          ),
        );
      case AppRouteTransition.scheduleFlow:
        return FadeTransition(
          opacity: _curvedOpacityAnimation(animation, begin: 0),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
    }
  }

  Animation<double> _curvedOpacityAnimation(
    Animation<double> animation, {
    required double begin,
  }) {
    return Tween<double>(
      begin: begin,
      end: 1,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
  }

  Animation<Offset> _curvedOffsetAnimation(
    Animation<double> animation, {
    required Offset begin,
  }) {
    return Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
  }
}
