import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/screens/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyB61_R9KigUpSsriTYFzYCPVVjDRJs8mFU",
        authDomain: "ontime-c63f1.firebaseapp.com",
        projectId: "ontime-c63f1",
        storageBucket: "ontime-c63f1.firebasestorage.app",
        messagingSenderId: "456571312261",
        appId: "1:456571312261:web:1d7c24d90acdc27d7e71ec",
        measurementId: "G-4TNCHRK7KR"),
  );
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: true,
    sound: true,
  );
  NotificationSettings settings = await messaging.getNotificationSettings();
  final token = await messaging.getToken();
  debugPrint('Token: $token');
  runApp(App());
}
