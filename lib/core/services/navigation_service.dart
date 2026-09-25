import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

@Singleton()
class NavigationService {
  final RouteObserver<PageRoute<dynamic>> routeObserver =
      RouteObserver<PageRoute<dynamic>>();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void push(String routeName, {Object? extra}) {
    GoRouter.of(navigatorKey.currentContext!).push(routeName, extra: extra);
  }

  void go(String routeName, {Object? extra}) {
    GoRouter.of(navigatorKey.currentContext!).go(routeName, extra: extra);
  }
}
