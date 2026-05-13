# Schedule State Reference

This document describes the schedule lifecycle as shared by the backend and Flutter. The backend owns persistence and edit locks. Flutter owns prompt, timer, and screen state derived from backend data plus local time.

## Source Of Truth

Server fields:

| Field | Values | Meaning |
| --- | --- | --- |
| `doneStatus` | `NOT_ENDED`, `NORMAL`, `LATE`, `ABNORMAL` | Persistent completion state. `NOT_ENDED` means the schedule is still active. The other values mean the schedule is finished. |
| `startedAt` | ISO-8601 datetime or `null` | Persistent preparation-start state. `null` means the user has not explicitly started preparation. Non-null means preparation has started and schedule editing is locked. |
| `finishedAt` | ISO-8601 datetime or `null` | Persistent explicit-finish state. Non-null means the finish endpoint completed for this schedule. |
| `latenessTime` | integer or `null` | Completion result. `-1` is legacy/unended data; new finish calls use `0` for normal or positive minutes for late. |
| `isStarted` | legacy boolean | Compatibility only. Flutter must not use this for lifecycle, edit locks, or bloc decisions. |

Derived server lifecycle:

| Server lifecycle | Predicate | Description |
| --- | --- | --- |
| Unstarted | `doneStatus == NOT_ENDED && startedAt == null` | Schedule exists and can still be edited. Flutter may show a start prompt when local time reaches the preparation window. |
| Started, unfinished | `doneStatus == NOT_ENDED && startedAt != null` | User has started preparation through `POST /schedules/{id}/start`. Schedule and schedule-specific preparation are frozen for editing. Running preparation uses the server snapshot. |
| Missed, unstarted | `doneStatus == NOT_ENDED && startedAt == null && scheduleTime < now` | User never started preparation. It is deletable and does not count toward punctuality score. |
| Finished normally | `doneStatus == NORMAL && finishedAt != null` | Schedule has explicitly ended without lateness. It is immutable and counts toward punctuality score. |
| Finished late | `doneStatus == LATE && finishedAt != null` | Schedule has explicitly ended late. It is immutable and counts toward punctuality score. |
| Finished abnormally | `doneStatus == ABNORMAL` | Schedule has ended through an abnormal finish path. It is immutable and excluded from punctuality score. |

## Backend Restrictions

| Operation | Unstarted | Started, unfinished | Finished |
| --- | --- | --- | --- |
| Read schedule | Allowed | Allowed | Allowed |
| Read preparation | Default or schedule-specific, depending on existing backend rules | Frozen schedule-specific snapshot | Historical/final data |
| `POST /schedules/{id}/start` | Allowed. Sets `startedAt` and freezes preparation snapshot. | Idempotent success. Must not replace `startedAt` or snapshot. | Reject with `SCHEDULE_ALREADY_FINISHED`. |
| Update schedule | Allowed | Reject with `SCHEDULE_ALREADY_STARTED`. | Reject with `SCHEDULE_ALREADY_FINISHED`. |
| Update schedule-specific preparation | Allowed | Reject with `SCHEDULE_ALREADY_STARTED`. | Reject with `SCHEDULE_ALREADY_FINISHED`. |
| Delete schedule | Allowed | Allowed | Reject with `SCHEDULE_ALREADY_FINISHED`. |
| Update default preparation template | Allowed | Allowed. Does not affect frozen started schedules. | Allowed. Does not affect finished schedules. |
| Finish schedule | Reject with `SCHEDULE_NOT_STARTED`. Missed/unstarted schedules stay `NOT_ENDED`. | Allowed. Sets `finishedAt` and final `doneStatus`. | Reject with `SCHEDULE_ALREADY_FINISHED`. |

Frontend action rules:

```text
canEditSchedule = doneStatus == notEnded && startedAt == null
canDeleteSchedule = doneStatus == notEnded
isServerStarted = startedAt != null
isExplicitlyFinished = finishedAt != null
isFinished = doneStatus != notEnded
includedInPunctualityScore =
  startedAt != null &&
  finishedAt != null &&
  doneStatus in (normalEnd, lateEnd)
```

`preparationStartTime` is only for prompts, timers, and countdown display. It must not be used as an edit-lock source.

## Flutter Bloc States

`ScheduleStatus` is runtime UI state, not persistent server state.

| Bloc state | Schedule present | Meaning | Server relationship | Main restrictions |
| --- | --- | --- | --- | --- |
| `initial` | No | Bloc has not resolved the nearest schedule yet. | Unknown. | No schedule actions. |
| `notExists` | No | No usable upcoming schedule, or the known schedule is stale/past/finished for the active flow. | No active `NOT_ENDED` schedule in the current runtime context. | No schedule actions. Alarm screen redirects home. |
| `upcoming` | Yes | Schedule is before `preparationStartTime`, or an alarm prompt has loaded a not-yet-started schedule. | Usually `doneStatus == notEnded && startedAt == null`. | Edit allowed only if `startedAt == null`; delete allowed if `notEnded`. Start can be offered as early start when user explicitly chooses it. |
| `readyToStart` | Yes | Local time is inside the preparation window, but backend has not set `startedAt`. The start prompt should be shown. | `doneStatus == notEnded && startedAt == null`. | Do not enter running preparation yet. User must tap start, which calls `POST /schedules/{id}/start`. Edit remains server-allowed until start succeeds, though UI should generally be on the start prompt. |
| `started` | Yes | Backend has set `startedAt`, or start API just returned a schedule with `startedAt`. Running preparation is active. | `doneStatus == notEnded && startedAt != null`. | Schedule/preparation edit locked. Delete still allowed while `doneStatus == notEnded`. Alarm screen can run timers and step progression. |
| `ongoing` | Yes | Legacy/runtime-compatible active state. Current code routes running preparation through `started`; some navigation helpers still treat `ongoing` as alarm-screen eligible. | Should be treated like an active running preparation state. | Same user-facing restrictions as `started` when used. |

Additional bloc fields:

| Field | Meaning |
| --- | --- |
| `isEarlyStarted` | Runtime flag for a schedule started before computed `preparationStartTime`. It affects timer catch-up behavior and UI, not server edit rules. |
| `isStartingPreparation` | Start request is in flight. Start buttons should be disabled and show loading. |
| `startError` | Retryable start failure message. The start screen stays open and must not navigate to alarm. |

## State Mapping

Backend data maps into Flutter state like this:

| Backend/server condition | Local time condition | Bloc state |
| --- | --- | --- |
| No upcoming schedule | Any | `notExists` |
| `scheduleTime < now` | Any | `notExists` |
| `doneStatus != NOT_ENDED` | Any active-flow context | `notExists` or redirect home, depending on entry point |
| `startedAt != null` | Any before `scheduleTime` | `started` |
| `startedAt == null` | `now < preparationStartTime` | `upcoming` |
| `startedAt == null` | `now == preparationStartTime` | `upcoming`, then `ScheduleStarted` moves to `readyToStart` and pushes `/scheduleStart` |
| `startedAt == null` | `preparationStartTime < now < scheduleTime` | `readyToStart` |

The important distinction:

```text
readyToStart = local time says the user should start, but server has not accepted start.
started      = server has accepted start and returned/persisted startedAt.
```

## Start Flow

1. Bloc receives an upcoming schedule from the repository stream.
2. If `startedAt == null` and local time reaches the preparation window, bloc emits `readyToStart`.
3. Flutter shows `/scheduleStart`.
4. User taps a start action.
5. Flutter dispatches `SchedulePreparationStarted`.
6. Bloc calls `StartScheduleUseCase`, which calls `POST /schedules/{scheduleId}/start`.
7. Backend sets `startedAt` if needed and returns:
   - updated schedule
   - frozen running preparation snapshot
8. Bloc replaces local schedule/preparation with the response and emits `started`.
9. `ScheduleStartScreen` navigates to `/alarmScreen` only after `started`.

On start failure:

1. Bloc keeps the previous schedule state.
2. `isStartingPreparation` becomes `false`.
3. `startError` is set.
4. The start screen remains visible and shows a retryable error.
5. The app must not navigate to `/alarmScreen`.

## Edit And Delete UI

Calendar schedule actions follow backend rules exactly:

| UI action | Visibility/enable rule | Reason |
| --- | --- | --- |
| Edit schedule | `doneStatus == notEnded && startedAt == null` | Started and finished schedules are immutable. |
| Delete schedule | `doneStatus == notEnded` | Started schedules may still be deleted until they are finished. |
| Hide all actions | `doneStatus != notEnded` | Finished schedules cannot be edited or deleted. |

The UI must not block editing just because computed `preparationStartTime` is in the past. Only `startedAt != null` and finished `doneStatus` lock editing.

## Preparation Snapshot Rules

Default preparation is a mutable template. Schedule-specific preparation after start is a frozen snapshot.

| Schedule condition | Preparation source |
| --- | --- |
| Unstarted and still using default preparation | Current default preparation may be resolved by backend. |
| Unstarted with schedule-specific preparation | Current schedule-specific preparation. |
| Started | Frozen schedule-specific snapshot returned by `POST /schedules/{id}/start`. |
| Finished | Finished schedule data. |

Changing default preparation after a schedule has started must not change that started schedule's frozen snapshot. Future or unstarted schedules may resolve the updated default template.

## Conflict Handling

When edit or preparation-update submissions fail with lifecycle conflicts, Flutter should show a clear message and refresh schedule data:

| Backend code | Meaning | Suggested frontend message |
| --- | --- | --- |
| `SCHEDULE_ALREADY_STARTED` | `startedAt` was set before or during the edit attempt. | This schedule has already started and can no longer be edited. |
| `SCHEDULE_ALREADY_FINISHED` | `doneStatus` is no longer `NOT_ENDED`. | This schedule has already finished and can no longer be edited. |
| `SCHEDULE_NOT_STARTED` | Finish was requested before `startedAt` was set. | Start preparation before finishing this schedule. |

After a lifecycle conflict, local state should be refreshed from the server so edit/delete controls match the authoritative lifecycle.
