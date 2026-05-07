# Logging Policy

OnTime logs must be safe by default. Release builds must not write tokens,
authorization headers, request bodies, response bodies, personal schedule
payloads, or full alarm launch payloads to device logs.

## Dart

- Use `AppLogger` for new diagnostics.
- `AppLogger` only emits logs in debug builds.
- Pass structured maps through `AppLogger.redactValue` or
  `AppLogger.redactMap` before including them in messages.
- Do not log request bodies, response bodies, OAuth values, FCM tokens,
  authorization headers, refresh tokens, schedule names, notes, or alarm
  payloads.
- If a token-related event needs diagnostics, log that the event happened and
  optionally include a redacted token length through `AppLogger.redactToken`.
- `main()` disables Flutter `debugPrint` in non-debug builds to prevent older
  debug diagnostics from leaking in release.

## Network

- Dio request and response logs may include method, redacted URL, status code,
  redacted headers, redacted query parameters, and body runtime type.
- Dio logs must not include serialized request bodies or response data.
- Add new sensitive header or parameter names to `AppLogger` redaction before
  logging them.

## Native Android and iOS

- Android native alarm diagnostics must use `NativeLog`, which emits only in
  debug builds.
- iOS native alarm diagnostics must be wrapped in `#if DEBUG`.
- Never log full `Intent` extras, AlarmKit encoded payloads, schedule titles,
  notification bodies, or launch URLs in release builds.

## Tests

Redaction behavior is covered by `test/core/logging/app_logger_test.dart`.
When adding a new sensitive key pattern, add or update a redaction test.
