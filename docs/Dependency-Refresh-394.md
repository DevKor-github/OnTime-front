# Dependency Refresh 394

This note documents the production-readiness dependency pass for GitHub issue
#394. The upgrade targets the versions resolvable by the project toolchain at
the time of the pass: Flutter 3.32.6 and Dart 3.8.1.

## Updated Scope

- Removed the direct dependency on the discontinued `js` package.
- Upgraded the production-critical batch covering Firebase, Google Sign-In,
  GoRouter, local notifications, secure storage, AppAuth, Drift, Freezed,
  GetIt, generator dependencies, and resolver-required transitive packages.
- Raised the app Dart SDK constraint to `^3.8.0` because the refreshed
  generator stack requires Dart 3.8.
- Updated Android build configuration for Java 17, AGP 8.6.0, Kotlin 2.0.20,
  Google Services 4.4.2, and minimum SDK 23.
- Raised iOS deployment targets to 15.0 because Firebase 12.12.0 declares an
  iOS 15.0 minimum, and aligned generated pod targets through the Podfile
  post-install hook.

## Verification

- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs`
- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `flutter build apk --debug`
- `pod install`
- `flutter build ios --debug --no-codesign`

## Deferred Packages

These packages were intentionally left below latest because the current task is
a critical-batch refresh, not a maximal all-dependency migration:

- `flutter_local_notifications` remains on 20.1.0 instead of 21.x.
- `flutter_appauth` remains on 11.0.0 instead of 12.x.
- `go_router` remains on 17.0.0 instead of 17.2.x.
- `google_sign_in_web` remains on 1.1.0 instead of 1.1.3.
- `kakao_flutter_sdk` and related Kakao packages remain on the 1.10.x line
  instead of 2.x.
- `sign_in_with_apple` remains on 7.0.1 instead of 8.x.
- `sqlite3_flutter_libs` remains on 0.5.42 instead of 0.6.0+eol.
- `json_annotation` remains on 4.9.0 because the resolver keeps it there.

## Follow-Up Smoke Areas

- Google sign-in on web and mobile.
- Token storage read/write/delete.
- Notification permission prompt and foreground FCM display.
- Scheduled fallback alarm notification and notification-tap navigation.
- Startup routing redirects.
