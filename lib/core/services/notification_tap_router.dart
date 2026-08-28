import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_routing.dart';

abstract interface class NotificationTapRouter {
  void routeLocalNotificationTap(String? payload);
}

class NoopNotificationTapRouter implements NotificationTapRouter {
  const NoopNotificationTapRouter();

  @override
  void routeLocalNotificationTap(String? payload) {}
}

@Singleton(as: NotificationTapRouter)
class NavigationNotificationTapRouter implements NotificationTapRouter {
  NavigationNotificationTapRouter(this._navigationService);

  final NavigationService _navigationService;

  @override
  void routeLocalNotificationTap(String? payload) {
    final target = notificationRouteForPayloadString(payload);
    _pushTarget(target);
  }

  void _pushTarget(NotificationRouteTarget? target) {
    if (target == null) return;
    _navigationService.push(target.path, extra: target.extra);
  }
}
