import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

@Singleton()
class NavigationService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void push(String routeName, {Object? extra}) {
    GoRouter.of(navigatorKey.currentContext!).push(routeName, extra: extra);
  }
}
