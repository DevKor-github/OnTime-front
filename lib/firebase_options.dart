// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB61_R9KigUpSsriTYFzYCPVVjDRJs8mFU',
    appId: '1:456571312261:web:1d7c24d90acdc27d7e71ec',
    messagingSenderId: '456571312261',
    projectId: 'ontime-c63f1',
    authDomain: 'ontime-c63f1.firebaseapp.com',
    storageBucket: 'ontime-c63f1.firebasestorage.app',
    measurementId: 'G-4TNCHRK7KR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBidmimBkVLWxS9r8O-e4vRuqDs7Lyijqk',
    appId: '1:456571312261:android:b3574e6f89d21a467e71ec',
    messagingSenderId: '456571312261',
    projectId: 'ontime-c63f1',
    storageBucket: 'ontime-c63f1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD9sTpL3rDqyuP8o7OQfVHJVcOgEyGuwRs',
    appId: '1:456571312261:ios:c2b75e7959945f717e71ec',
    messagingSenderId: '456571312261',
    projectId: 'ontime-c63f1',
    storageBucket: 'ontime-c63f1.firebasestorage.app',
    iosClientId: '456571312261-r35ah9qi0qaq7al007e2db0e0jmjcmb4.apps.googleusercontent.com',
    iosBundleId: 'club.devkor.ontime',
  );
}
