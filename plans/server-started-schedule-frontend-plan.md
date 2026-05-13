# Frontend Plan: Server-Authoritative Schedule Start

## Summary

Update Flutter so backend `startedAt` is the source of truth for whether schedule preparation has explicitly started. The app must call `POST /schedules/{scheduleId}/start` only when the user taps **Start preparation**, use the returned schedule and frozen preparation payload as authoritative, and prevent schedule/preparation edits when `startedAt != null`.

Add `ScheduleStatus.readyToStart` so `ScheduleStatus.started` means exactly: backend has set `startedAt`.

Preparation lifecycle:

- Default preparation is a mutable template.
- Started schedule preparation is a schedule-specific frozen snapshot.
- After `startedAt` is set, schedule preparation reads come from the frozen snapshot returned by the server, not from the user's default preparation.

## Backend Contract

All endpoints use the current OnTime access token and existing Dio auth flow:

```http
Authorization: Bearer {accessToken}
Content-Type: application/json
```

Schedule responses include nullable `startedAt`:

```json
{
  "scheduleId": "3fa85f64-5717-4562-b3fc-2c963f66afe5",
  "place": {
    "placeId": "70d460da-6a82-4c57-a285-567cdeda5670",
    "placeName": "Home"
  },
  "scheduleName": "Party",
  "moveTime": 20,
  "scheduleTime": "2026-05-13T19:30:00",
  "scheduleSpareTime": 20,
  "scheduleNote": "Write a message.",
  "latenessTime": -1,
  "doneStatus": "NOT_ENDED",
  "startedAt": "2026-05-13T10:15:30Z"
}
```

Start endpoint:

```http
POST /schedules/{scheduleId}/start
```

Request body: none.

Success response:

```json
{
  "status": "success",
  "code": 200,
  "message": "OK",
  "data": {
    "schedule": {
      "scheduleId": "3fa85f64-5717-4562-b3fc-2c963f66afe5",
      "place": {
        "placeId": "70d460da-6a82-4c57-a285-567cdeda5670",
        "placeName": "Home"
      },
      "scheduleName": "Party",
      "moveTime": 20,
      "scheduleTime": "2026-05-13T19:30:00",
      "scheduleSpareTime": 20,
      "scheduleNote": "Write a message.",
      "latenessTime": -1,
      "doneStatus": "NOT_ENDED",
      "startedAt": "2026-05-13T10:15:30Z"
    },
    "preparations": [
      {
        "preparationId": "123e4567-e89b-12d3-a456-426614174011",
        "preparationName": "Wash up",
        "preparationTime": 10,
        "nextPreparationId": "123e4567-e89b-12d3-a456-426614174012"
      }
    ]
  }
}
```

Lifecycle errors use `409` with stable codes:

```json
{
  "status": "error",
  "code": "SCHEDULE_ALREADY_STARTED",
  "message": "Started schedules cannot be edited.",
  "data": null
}
```

```json
{
  "status": "error",
  "code": "SCHEDULE_ALREADY_FINISHED",
  "message": "Finished schedules cannot be edited.",
  "data": null
}
```

Frontend rules:

```text
canEditSchedule = doneStatus == NOT_ENDED && startedAt == null
canDeleteSchedule = doneStatus == NOT_ENDED
```

## Implementation Changes

### Models and API

- Add nullable `DateTime? startedAt` to `ScheduleEntity` and carry it through `ScheduleWithPreparationEntity`.
- Keep `isStarted` as temporary compatibility, but stop using it for edit locks or bloc decisions.
- Parse `startedAt` from schedule response DTOs, including `GetScheduleResponseModel` and `AlarmWindowScheduleModel`.
- Add `Endpoint.startSchedule(String scheduleId) => '/schedules/$scheduleId/start'`.
- Add a start response model that maps `data.schedule` to `ScheduleEntity` and `data.preparations` to `PreparationEntity`.
- Add a domain result object such as `StartedScheduleEntity(schedule, preparation)`.
- Add:
  - `ScheduleRemoteDataSource.startSchedule(String scheduleId)`
  - `ScheduleRepository.startSchedule(String scheduleId)`
  - `StartScheduleUseCase`
- On successful start, repository upserts the returned schedule into the schedule stream/cache and returns the frozen preparation snapshot.

### Bloc and Runtime Flow

- Add `ScheduleStatus.readyToStart`.
- Emit `started` only when the current schedule has `startedAt != null`, or after the start endpoint succeeds and returns a schedule with `startedAt`.
- Emit `readyToStart` when local timing says the start prompt should show but `startedAt == null`.
- Local `preparationStartTime` still drives prompt timing and countdowns, but never determines edit locking or server-started state.
- In `SchedulePreparationStarted`:
  - call `StartScheduleUseCase`;
  - replace the current schedule with the returned schedule;
  - replace the current running preparation with `data.preparations`;
  - emit `ScheduleState.started`;
  - start the preparation timer.
- If start fails, do not emit `started` and do not navigate to `/alarmScreen`. Keep the user on the start screen with retry feedback.
- Existing persisted timed-preparation restore should only be used when compatible with server-started state. Once start succeeds, use the backend frozen preparation as the running baseline.

### Start Screen and Navigation

- `ScheduleStartScreen` should dispatch `SchedulePreparationStarted` for all prompt variants, including official start, early start, and alarm prompt.
- Remove immediate `context.go('/alarmScreen')` from the start button.
- Add UI feedback while start is in flight.
- On start failure, stay on the prompt and show retryable feedback.
- Navigate to `/alarmScreen` from a listener only after `ScheduleBloc` emits `ScheduleStatus.started`.

### Edit, Delete, and Form Errors

- Update `ScheduleDetail`:
  - edit action visible only when `doneStatus == notEnded && startedAt == null`;
  - delete action visible only when `doneStatus == notEnded`;
  - do not hide edit solely because `DateTime.now()` passed computed `preparationStartTime`.
- Update today tile navigation for `readyToStart`:
  - `upcoming` and `readyToStart` should route to `/scheduleStart`;
  - `started` should route to `/alarmScreen`.
- Update schedule/preparation edit submission error handling:
  - `SCHEDULE_ALREADY_STARTED`: show "This schedule has already started and can no longer be edited.", refresh schedule data, and keep the form in failure UX.
  - `SCHEDULE_ALREADY_FINISHED`: show "This schedule has already finished and can no longer be edited.", refresh schedule data, and keep the form in failure UX.
- Default preparation editing remains allowed and should not special-case active schedules. Started schedules use their frozen server snapshot.

## Test Plan

- Model tests:
  - schedule response maps `startedAt: null`;
  - schedule response maps non-null UTC `startedAt`;
  - start response maps `data.schedule` and `data.preparations`.
- Data/repository tests:
  - start API posts to `/schedules/{id}/start` with no request body;
  - successful start upserts the returned schedule;
  - returned frozen preparation is exposed to the caller.
- Bloc tests:
  - crossing preparation start time emits `readyToStart`, not `started`;
  - `SchedulePreparationStarted` calls start use case;
  - start success emits `started` with returned schedule/preparation;
  - start failure stays out of `started`;
  - fetched schedule with non-null `startedAt` restores as `started`.
- UI/widget tests:
  - start screen shows loading/error/retry and navigates only after `started`;
  - edit action hidden when `startedAt != null`;
  - delete action remains available when `startedAt != null && doneStatus == notEnded`;
  - edit/delete hidden or disabled when `doneStatus != notEnded`.
- Regression:

```sh
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

## Rollout Notes

1. Backend deploys nullable `startedAt`, schedule response field, idempotent start endpoint, frozen preparation response, and update guards.
2. Flutter adds `startedAt` parsing and start endpoint integration while keeping `isStarted` request compatibility.
3. Flutter switches runtime start flow to server-authoritative `startedAt`.
4. Flutter switches edit/delete UI guards to `startedAt` and `doneStatus`.
5. After backend confirms old clients are upgraded, Flutter removes `isStarted` from create requests.
6. Backend removes deprecated `isStarted` support and DB column.
