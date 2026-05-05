# Backend Specification: Native Alarm Feature

## Goal

Support account-owned schedules while allowing exactly one logged-in device to mirror upcoming schedules into local native alarms.

The server remains the source of truth for schedules and preparation data. Native alarm scheduling remains device-local because Android AlarmManager, iOS AlarmKit, and local notification fallback are OS/device capabilities.

## Product Decisions

- Alarm trigger time is 5 minutes before `preparationStartTime`.
- `preparationStartTime = scheduleTime - moveTime - scheduleSpareTime - totalPreparationTime`.
- Device-local time is accepted for v1.
- `scheduleTime`, `preparationStartTime`, and `defaultAlarmTime` represent the user's intended local wall-clock time in v1.
- Only one device is logged in at a time.
- The client reconciles all not-ended schedules in the next 7 days.
- The client does not schedule past alarms.
- Schedule create/update should succeed even if alarm setup is incomplete.
- Global alarms setting ships first.
- Future server-backed per-schedule alarm settings should be designed into the contract.

## V1 Backend Scope

Backend must keep schedule and preparation APIs as source of truth and add user alarm preference/device metadata APIs. Backend does not schedule native alarms.

Required backend responsibilities:

- Persist user-level alarm preference.
- Persist current device identity for the authenticated user.
- Enforce or support one active device session, if not already implemented.
- Suppress legacy server push reminders only when latest current-device alarm status indicates local alarm coverage, to avoid duplicate alerts without leaving unarmed users silent.
- Return enough schedule and preparation data for the client to compute alarm times.
- Expose a required 7-day schedule/preparation alarm-window sync path efficient enough for alarm reconciliation.
- Store the latest per-device alarm status as durable but non-authoritative diagnostics for settings UI and support.

Out of scope for v1:

- Server-sent alarm jobs.
- Backend-triggered alarm fallback.
- Per-schedule alarm settings enforcement.
- Multi-device alarm arbitration.

## Data Model Additions

### User Alarm Settings

Store one row/document per user.

```json
{
  "userId": "string",
  "alarmsEnabled": true,
  "defaultAlarmOffsetMinutes": 5,
  "updatedAt": "2026-05-05T09:00:00.000Z"
}
```

Rules:

- `alarmsEnabled` controls whether the client should mirror schedules into local alarms.
- `defaultAlarmOffsetMinutes` defaults to `5`.
- Backend stores `defaultAlarmOffsetMinutes` in v1, but the client UI keeps the offset fixed at 5 minutes.
- For v1, this is global and applies to all schedules.
- When `alarmsEnabled=false`, client cancels local alarms but server schedules remain unchanged.
- When `alarmsEnabled=true`, backend should suppress legacy 5-minute-before push reminders only when the latest current-device alarm status indicates local coverage.
- Suppression applies when latest status is `armed`, or `partial` with provider coverage and at least one armed schedule.
- If status is `partial`, backend should suppress legacy push only for `armedScheduleIds` and may send legacy push for failed or missing eligible schedules.
- Backend should suppress only for schedules inside the reported alarm coverage window and listed in `armedScheduleIds`.
- Latest status is eligible for suppression only when `reconciledAt` is within the last 24 hours and belongs to the current active `deviceId`/session.
- Backend may continue legacy push reminders when latest status is `permissionNeeded`, `unsupported`, `settingsUnavailable`, missing, or stale.
- Client-reported `armedScheduleIds` are a best-effort suppression signal. If backend is uncertain, it should send the legacy push rather than risk silence.
- When `alarmsEnabled=false`, backend may continue legacy push reminder behavior if the product wants backward compatibility.

### Device Registration

Store one active device per user.

```json
{
  "deviceId": "uuid-or-installation-id",
  "userId": "string",
  "platform": "android|ios",
  "appVersion": "string",
  "osVersion": "string",
  "supportsNativeAlarm": true,
  "nativeAlarmProvider": "androidAlarmManager|iosAlarmKit|none",
  "fallbackProvider": "localNotification|none",
  "lastSeenAt": "2026-05-05T09:00:00.000Z"
}
```

Rules:

- On login, client registers or updates the current device.
- `deviceId` is an opaque client-generated installation identifier.
- Validate `deviceId` as a required bounded string, recommended length 16-128 with safe identifier characters such as letters, numbers, `.`, `_`, `:`, and `-`.
- If the product guarantees one logged-in device, registering a new device may invalidate older device sessions/tokens.
- Logout should unregister or mark the device inactive.
- Device metadata is diagnostic and helps backend/customer support understand alarm availability.

### Future Per-Schedule Alarm Settings

Do not require this for v1, but reserve fields or prepare a table for later.

```json
{
  "scheduleId": "string",
  "userId": "string",
  "alarmEnabled": true,
  "alarmOffsetMinutes": 5,
  "deliveryPreference": "nativeFirst|notificationOnly|off",
  "updatedAt": "2026-05-05T09:00:00.000Z"
}
```

Future rules:

- Per-schedule settings override user defaults.
- Global `alarmsEnabled=false` remains a device/user-level override that prevents local arming.
- These settings must survive device changes.

## API Contracts

### Get Alarm Settings

`GET /users/me/alarm-settings`

Response:

```json
{
  "data": {
    "alarmsEnabled": true,
    "defaultAlarmOffsetMinutes": 5,
    "updatedAt": "2026-05-05T09:00:00.000Z"
  }
}
```

### Patch Alarm Settings

`PATCH /users/me/alarm-settings`

Request:

```json
{
  "alarmsEnabled": true
}
```

Response:

```json
{
  "data": {
    "alarmsEnabled": true,
    "defaultAlarmOffsetMinutes": 5,
    "updatedAt": "2026-05-05T09:00:00.000Z"
  }
}
```

Validation:

- Request fields are optional, but at least one supported field must be present.
- Unknown fields should be rejected with `400 Bad Request` and error code `ALARM_SETTINGS_INVALID_FIELD`.
- `defaultAlarmOffsetMinutes` must be `>= 0`.
- Recommended max is `1440`.

### Register Current Device

`PUT /users/me/devices/current`

Request:

```json
{
  "deviceId": "4f78cdd2-2d90-43b8-8bc5-53df8d9c5b12",
  "platform": "ios",
  "appVersion": "1.4.0",
  "osVersion": "26.0",
  "supportsNativeAlarm": true,
  "nativeAlarmProvider": "iosAlarmKit",
  "fallbackProvider": "localNotification"
}
```

Response:

```json
{
  "data": {
    "deviceId": "4f78cdd2-2d90-43b8-8bc5-53df8d9c5b12",
    "active": true,
    "lastSeenAt": "2026-05-05T09:00:00.000Z"
  }
}
```

Server behavior:

- Associate this device with the authenticated user.
- Bind this device to the current authenticated access/refresh-token session.
- If only one logged-in device is allowed, invalidate or deactivate previous devices for the same user.
- This endpoint should be idempotent.
- Validate `platform`, `nativeAlarmProvider`, and `fallbackProvider` as enums.
- Reject impossible platform/provider combinations, such as `platform=ios` with `nativeAlarmProvider=androidAlarmManager`.
- Backend cannot directly cancel OS alarms on an old disconnected device.
- Old-device local alarms must be canceled by the old app when it receives logout/session-invalidated handling or next observes an auth failure.

### Unregister Current Device

`DELETE /users/me/devices/current`

Request body optional:

```json
{
  "deviceId": "4f78cdd2-2d90-43b8-8bc5-53df8d9c5b12"
}
```

Response:

```json
{
  "data": {
    "active": false
  }
}
```

### Register FCM Token

Existing endpoint: `POST /firebase-token`

Update the request to include `deviceId` so push tokens can be associated with the current active device.

Request:

```json
{
  "firebaseToken": "string",
  "deviceId": "4f78cdd2-2d90-43b8-8bc5-53df8d9c5b12"
}
```

Rules:

- `/users/me/devices/current` owns device/session metadata.
- `/firebase-token` owns push token registration and links the FCM token to the current device.
- Backend should consider a transition period if older clients still send only `firebaseToken`.

### Alarm Window Sync

`GET /schedules/alarm-window?startDate=2026-05-05T00:00:00.000Z&endDate=2026-05-12T00:00:00.000Z`

Response:

```json
{
  "data": [
    {
      "scheduleId": "string",
      "scheduleName": "Dentist",
      "place": {
        "placeId": "string",
        "placeName": "Gangnam Station"
      },
      "scheduleTime": "2026-05-06T10:00:00.000",
      "moveTime": 30,
      "scheduleSpareTime": 10,
      "doneStatus": "NOT_ENDED",
      "preparationStartTime": "2026-05-06T08:55:00.000",
      "defaultAlarmTime": "2026-05-06T08:50:00.000",
      "preparations": [
        {
          "preparationId": "string",
          "preparationName": "Shower",
          "preparationTime": 20,
          "nextPreparationId": "string-or-null"
        }
      ],
      "alarmSettings": null
    }
  ]
}
```

Notes:

- `startDate` and `endDate` use the same format and semantics as the existing `GET /schedules` date range API.
- Backend interprets query bounds as local wall-clock schedule bounds for v1.
- Endpoint is not paginated in v1.
- Backend rejects ranges longer than 14 days.
- Date range is inclusive start and exclusive end: include schedules where `scheduleTime >= startDate && scheduleTime < endDate`.
- Client should request an 8-day padded schedule window for 7-day alarm coverage.
- If the requested range is longer than 14 days, backend returns `400 Bad Request` with error code `ALARM_WINDOW_RANGE_TOO_LONG`.
- `scheduleTime` remains device-local for v1, matching current client behavior.
- `place` includes only minimal display data needed for local alarm text.
- `moveTime`, `scheduleSpareTime`, and `preparationTime` are non-negative integer minutes.
- `scheduleSpareTime` should be `0`, not `null`, when no spare time exists.
- `preparations: []` is allowed when a schedule truly has no preparation steps; client treats total preparation time as zero.
- Backend should not silently return `preparations: []` when preparation loading failed server-side.
- `doneStatus` must be included so client filters `NOT_ENDED`.
- `alarmSettings` is `null` for v1, reserved for future per-schedule settings.
- Backend filters by `scheduleTime` range and `doneStatus=NOT_ENDED`.
- Backend returns schedules sorted by `scheduleTime ASC, scheduleId ASC`.
- Client should request a padded schedule window, such as `now` through `now + 8 days`, then arm only computed alarm times within `now` through `now + 7 days`.
- `preparationStartTime` and `defaultAlarmTime` are optional convenience/debug fields.
- Client remains responsible for computing final alarm time from raw schedule, preparation, and alarm settings data.
- Time fields represent local wall-clock schedule time in v1. Do not silently convert them in a way that changes the user's intended appointment time.
- Future timezone-stable behavior should add a `scheduleTimezone` field, such as `Asia/Seoul`.

This endpoint is required for v1 because alarms default on and reconciliation runs on login, launch, resume, and schedule mutation boundaries.

### Alarm Status Report

`POST /users/me/alarm-status`

Request:

```json
{
  "deviceId": "4f78cdd2-2d90-43b8-8bc5-53df8d9c5b12",
  "reconciledAt": "2026-05-05T09:00:00.000Z",
  "scheduleWindowStart": "2026-05-05T00:00:00.000",
  "scheduleWindowEnd": "2026-05-13T00:00:00.000",
  "alarmCoverageStart": "2026-05-05T00:00:00.000",
  "alarmCoverageEnd": "2026-05-12T00:00:00.000",
  "status": "armed|partial|disabled|permissionNeeded|unsupported|settingsUnavailable",
  "permissionIssue": "nativePermissionDenied|notificationPermissionDenied|null",
  "nativeAlarmProvider": "androidAlarmManager|iosAlarmKit|none",
  "fallbackProvider": "localNotification|none",
  "armedScheduleCount": 4,
  "armedScheduleIds": ["schedule-id-1", "schedule-id-2"],
  "skippedScheduleCount": 2,
  "failures": [
    {
      "scheduleId": "schedule-id-1",
      "reason": "preparationLoadFailed"
    }
  ]
}
```

Response:

```json
{
  "data": {
    "received": true
  }
}
```

Server behavior:

- Store only the latest status for the authenticated user's current device.
- Reject reports from inactive or non-current devices with `409 Conflict` and error code `DEVICE_SESSION_NOT_ACTIVE`.
- Treat status as diagnostic and non-authoritative.
- Do not use this status to decide whether schedules are valid or guarantee whether local alarms will fire.
- Backend may use latest current-device status as a best-effort duplicate-alert suppression signal for legacy push reminders.
- Use it for My Page status display, support diagnostics, and debugging missed alarms.
- `armedScheduleIds` means schedules covered by any accepted local delivery method, including native alarms and local notification fallback.
- Do not add a custom `armedScheduleIds` count cap in v1 beyond normal API request body limits.
- Status definitions:
  - `armed`: no eligible schedule failed to arm; zero eligible schedules is still healthy.
  - `partial`: at least one eligible schedule could not be armed.
  - `disabled`: global alarms are disabled.
  - `permissionNeeded`: required native alarm or fallback notification permission/setup is missing.
  - `settingsUnavailable`: alarm settings could not be loaded.
  - `unsupported`: no native alarm and no acceptable fallback are available.
- `unsupported` is a top-level platform/provider state, not a per-schedule failure.
- If local notification fallback is active, report `status=armed` or `status=partial` with `nativeAlarmProvider=none` and `fallbackProvider=localNotification`, not `unsupported`.
- Failure reasons should be coarse and non-sensitive.
- `permissionIssue` is a top-level device/provider issue and should not be repeated per schedule.
- Supported failure reasons: `preparationLoadFailed`, `scheduleInvalid`, `platformError`, `unknown`.
- Past alarm times are skipped by design and should be counted in `skippedScheduleCount`, not reported as failures.

## Existing Schedule API Requirements

The current schedule APIs must preserve these fields:

- `scheduleId`
- `scheduleName`
- `scheduleTime`
- `moveTime`
- `scheduleSpareTime`
- `doneStatus`

The preparation API must preserve:

- `preparationId`
- `preparationName`
- `preparationTime`
- `nextPreparationId`

Backend must ensure `doneStatus` is accurate after finish/delete/update operations so the client cancels stale alarms.

`/schedules/alarm-window` should omit `scheduleNote` because alarm computation and local alarm display do not require private note content.

## Client Reconciliation Contract

Backend provides data. Client computes:

```text
totalPreparationTime = sum(preparation.preparationTime)
preparationStartTime = scheduleTime - moveTime - scheduleSpareTime - totalPreparationTime
alarmTime = preparationStartTime - defaultAlarmOffsetMinutes
```

Client schedules only when:

- User is authenticated.
- Global `alarmsEnabled=true`.
- `doneStatus == NOT_ENDED`.
- `now < alarmTime`.
- `alarmTime <= now + 7 days`.
- Preparation data loaded successfully.

The client should request the alarm-window endpoint by `scheduleTime` with a padded range, then perform final eligibility filtering by computed `alarmTime`.

Client cancels local alarms when:

- Global alarms are disabled.
- User logs out.
- User session is invalidated by login on another device.
- Backend returns `DEVICE_SESSION_NOT_ACTIVE`.
- Schedule is deleted, finished, ended, or no longer in desired window.
- Schedule/preparation fingerprint changes.
- User starts preparation early.

## Error Handling

- Schedule create/update/delete/finish must not fail because local alarm setup fails.
- If alarm settings API fails, client should keep schedule operations successful and retry alarm settings/reconciliation later.
- If alarm settings cannot be loaded during reconciliation, client should not arm new alarms, should not immediately cancel existing registered alarms, should report `settingsUnavailable`, and should retry later.
- If preparation data cannot be loaded, client skips that schedule alarm and reports partial status through the alarm status API.
- If device registration fails, client can still use local alarms, but status reporting/device ownership may be degraded.

## Security

- All endpoints require authenticated user tokens.
- Users can only access their own alarm settings, devices, schedules, and status reports.
- Device IDs are client-generated installation identifiers, not hardware identifiers.
- Do not store sensitive OS permission details beyond coarse support/status fields.

## Migration

Default values for existing and new users:

```json
{
  "alarmsEnabled": true,
  "defaultAlarmOffsetMinutes": 5
}
```

Recommended rollout:

1. Add alarm settings storage and APIs.
2. Add device registration APIs.
3. Add alarm-window aggregate endpoint.
4. Confirm existing schedule and preparation APIs remain backward compatible.
5. Add alarm status report endpoint.
6. Later add per-schedule alarm settings.
