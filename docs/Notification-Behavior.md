# Notification Behavior

This document describes the current notification behavior in OnTime across push (FCM) and local notifications, based on implementation as of March 21, 2026.

## 1. Initialization & Permission Gate

- App startup checks current notification permission first.
- `NotificationService.initialize()` runs at startup only when permission is already `AuthorizationStatus.authorized`.
- If startup permission is not authorized, the app does not initialize notification handlers/tokens from `main.dart`.
- During authenticated redirects from sign-in/onboarding entry routes, router logic checks permission and redirects to `/allowNotification` when permission is not authorized.
- Permission can later be requested from:
  - Notification allow screen (`/allowNotification`)
  - My Page > App Settings > Allow App Notifications

Implementation notes:
- `main.dart` gates initialization by `checkNotificationPermission()`.
- `go_router.dart` performs the `/allowNotification` redirect check.
- `notification_allow_screen.dart` and `my_page_screen.dart` run permission request/setting flows and call `NotificationService.initialize()` once authorized.

## 2. Push Notification Flow (Foreground/Background/Terminated)

### Foreground

- `FirebaseMessaging.onMessage` listener is registered in `NotificationService._setupMessageHandlers()`.
- Incoming push messages are converted into in-app local notifications through `showNotification(message)`.
- Title/body resolution supports both `message.notification` and `message.data` keys (e.g., `title`, `content`, `body`, plus case variants).

### Background (App in background, opened from notification)

- `FirebaseMessaging.onMessageOpenedApp` triggers `_handleBackgroundMessage(message)`.
- Navigation is decided from payload fields:
  - `type` contains `5min` -> push `/scheduleStart` with `extra: {'isFiveMinutesBefore': true}`
  - `type` starts with `schedule_` or `preparation_`, or `scheduleId` exists -> push `/alarmScreen`

### Terminated (Cold start from notification tap)

- `FirebaseMessaging.getInitialMessage()` is read on initialization.
- If present, it is passed through the same `_handleBackgroundMessage(message)` routing logic as background open.

### Background isolate handler

- `_firebaseMessagingBackgroundHandler` initializes Firebase, ensures local notification plugin setup, and calls `showNotification(message)`.

## 3. Local Notification Flow (Schedule Step Changes)

- Local notifications for preparation steps are emitted by `ScheduleBloc` via `_notifyPreparationStep` callback (default: `NotificationService.instance.showPreparationStepNotification`).
- Trigger condition:
  - Current preparation step changed (`oldCurrentStep.id != newCurrentStep.id`)
  - New step is not null
  - New step is not the first step
  - Preparation is not fully done
  - Step has not already been notified for the same schedule
- Deduping:
  - `ScheduleBloc` tracks notified step IDs in `_notifiedStepIdsByScheduleId`.
  - Each step is notified once per schedule instance.
- Notification content:
  - Title: `[$scheduleName] $preparationName`
  - Body: localized (`ko`: "이어서 준비하세요.", `en`: "Continue preparing")
  - Payload: `{'type': 'preparation_step', 'scheduleId': ..., 'stepId': ...}`

## 4. Tap Handling & Route Navigation

### Local notification tap

- Local notification taps are handled through `FlutterLocalNotificationsPlugin.initialize(... onDidReceiveNotificationResponse ...)`.
- Payload JSON is parsed in `_handleLocalNotificationTap`.
- Routing rules match push open behavior:
  - `type` contains `5min` -> `/scheduleStart` with `isFiveMinutesBefore`
  - `type` starts with `schedule_` or `preparation_`, or `scheduleId` exists -> `/alarmScreen`

### Push open routing summary

- Push-open routing (`onMessageOpenedApp`, `getInitialMessage`) and local-tap routing both converge on the same payload-driven destination rules above.

## 5. Token Registration & Refresh

- On notification service initialization:
  - `FirebaseMessaging.getToken()` is called.
  - If token exists, app posts to backend endpoint `/firebase-token` with payload `{ "firebaseToken": "<token>" }`.
- On token refresh:
  - `FirebaseMessaging.onTokenRefresh.listen(...)` posts refreshed token to the same endpoint.
- Failures are logged and do not crash app flow.

## 6. Platform-Specific Notes (Android/iOS/Web)

### Android

- `POST_NOTIFICATIONS` permission declared in Android manifest.
- App creates Android channel:
  - ID: `high_importance_channel`
  - Importance: high
  - Used for both push-mirrored and app-triggered local notifications.

### iOS

- `Info.plist` includes `UIBackgroundModes` with `fetch` and `remote-notification`.
- `AppDelegate.swift` sets APNs token with `Messaging.messaging().apnsToken = deviceToken`.
- Foreground display options are explicitly enabled (`alert`, `badge`, `sound`) in notification service initialization.

### Web

- Web JS bridge exposes:
  - `_requestNotificationPermission` -> `Notification.requestPermission()`
  - `_isInStandaloneMode`
- `index.html` registers `firebase-messaging-sw.js`.
- Service worker listens for `push` events and shows browser notification from payload data (`data.data.title`, `data.data.content`) when permission is granted.

## 7. Known Behavioral Caveats / Edge Cases

- Startup gap when permission is granted later:
  - Since `main.dart` only auto-initializes when already authorized, users who grant permission later depend on in-app paths (`/allowNotification` or My Page flow) to call `NotificationService.initialize()`.
- Redirect scope nuance:
  - Router permission redirect to `/allowNotification` is applied in authenticated flow when coming through sign-in/onboarding entry routes, not as a global guard on every route.
- Payload-shape dependency:
  - Routing depends on `type` and/or `scheduleId` payload keys; unexpected payload formats may not navigate.
- No scheduled local alarms:
  - Local notifications in current implementation are immediate `show(...)` calls, not time-scheduled notifications.

## Source Of Truth (Key Files)

- `lib/core/services/notification_service.dart`
- `lib/presentation/app/bloc/schedule/schedule_bloc.dart`
- `lib/presentation/shared/router/go_router.dart`
- `lib/presentation/notification_allow/screens/notification_allow_screen.dart`
- `lib/presentation/my_page/my_page_screen.dart`
- `lib/main.dart`
- `lib/data/data_sources/notification_remote_data_source.dart`
- Web notification bridge + worker:
  - `web/functions.js`
  - `web/firebase-messaging-sw.js`
- Platform notification config:
  - `android/app/src/main/AndroidManifest.xml`
  - `ios/Runner/Info.plist`
  - `ios/Runner/AppDelegate.swift`

## Verification Checklist

Use this checklist when validating behavior manually or during regression checks.

- Permission not authorized on launch:
  - Confirm startup does not initialize notification service automatically.
- Permission granted from allow screen:
  - Confirm permission request flow can initialize service and proceed to home.
- Foreground push display:
  - Confirm push while app is foregrounded appears as local notification.
- Tap routing:
  - `type` containing `5min` routes to `/scheduleStart` with five-minute variant.
  - `schedule_*` / `preparation_*` / payload with `scheduleId` routes to `/alarmScreen`.
- Local step-change notification:
  - Confirm first step does not notify, subsequent step transitions notify once each.
- Token registration:
  - Confirm token post on initialize and on token refresh (`/firebase-token`).

Reference test:
- `test/presentation/app/bloc/schedule/schedule_bloc_test.dart`
  - `step change notification fires for non-first transitions only once`
