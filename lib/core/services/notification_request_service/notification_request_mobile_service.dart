import 'package:firebase_messaging/firebase_messaging.dart';

Future<String> requestNotificationPermission() {
  final settings = FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
    announcement: false,
    carPlay: false,
    criticalAlert: false,
  );
  return settings.then((value) => value.authorizationStatus.toString());
}
