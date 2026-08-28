import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';

void main() {
  test('routes local notification payloads through navigation service', () {
    final navigationService = _FakeNavigationService();
    final router = NavigationNotificationTapRouter(navigationService);

    router.routeLocalNotificationTap(
      '{"type":"preparation_step","scheduleId":"schedule-1"}',
    );
    router.routeLocalNotificationTap('not-json');

    expect(navigationService.pushedRoutes, ['/alarmScreen']);
  });
}

class _FakeNavigationService implements NavigationService {
  final pushedRoutes = <String>[];
  final pushedExtras = <Object?>[];

  @override
  void push(String routeName, {Object? extra}) {
    pushedRoutes.add(routeName);
    pushedExtras.add(extra);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
