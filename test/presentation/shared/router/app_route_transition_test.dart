import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/router/app_route_transition.dart';

void main() {
  testWidgets('standard app route fades and glides into place', (tester) async {
    final page = buildAppRoutePage<void>(
      key: const ValueKey('standard-route'),
      child: const SizedBox(key: Key('route_child')),
      transition: AppRouteTransition.standard,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => page.transitionsBuilder(
            context,
            const AlwaysStoppedAnimation<double>(0.5),
            const AlwaysStoppedAnimation<double>(0),
            page.child,
          ),
        ),
      ),
    );

    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
    final slide = tester.widget<SlideTransition>(find.byType(SlideTransition));

    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
    expect(slide.position.value.dy, greaterThan(0));
    expect(slide.position.value.dy, lessThan(0.04));
    expect(slide.position.value.dx, 0);
  });

  testWidgets('standard app route exits back toward its entry edge', (
    tester,
  ) async {
    final page = buildAppRoutePage<void>(
      key: const ValueKey('standard-route'),
      child: const SizedBox(key: Key('route_child')),
      transition: AppRouteTransition.standard,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => page.transitionsBuilder(
            context,
            const AlwaysStoppedAnimation<double>(0),
            const AlwaysStoppedAnimation<double>(0),
            page.child,
          ),
        ),
      ),
    );

    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
    final slide = tester.widget<SlideTransition>(find.byType(SlideTransition));

    expect(fade.opacity.value, lessThan(0.1));
    expect(slide.position.value.dy, greaterThan(0));
    expect(slide.position.value.dx, 0);
  });

  testWidgets('bottom navigation routes exit back toward their entry edge', (
    tester,
  ) async {
    Future<Offset> popOffsetFor(AppRouteTransition transition) async {
      final page = buildAppRoutePage<void>(
        key: ValueKey('route-$transition'),
        child: const SizedBox(key: Key('route_child')),
        transition: transition,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => page.transitionsBuilder(
              context,
              const AlwaysStoppedAnimation<double>(0),
              const AlwaysStoppedAnimation<double>(0),
              page.child,
            ),
          ),
        ),
      );

      return tester
          .widget<SlideTransition>(find.byType(SlideTransition))
          .position
          .value;
    }

    final homePopOffset = await popOffsetFor(
      AppRouteTransition.bottomNavFromLeft,
    );
    final myPagePopOffset = await popOffsetFor(
      AppRouteTransition.bottomNavFromRight,
    );

    expect(homePopOffset.dx, lessThan(0));
    expect(homePopOffset.dy, 0);
    expect(myPagePopOffset.dx, greaterThan(0));
    expect(myPagePopOffset.dy, 0);
  });
}
