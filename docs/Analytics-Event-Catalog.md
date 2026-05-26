# Analytics Event Catalog

This catalog defines the first-release Product Usage Events for OnTime. Events are Workflow Milestone Events only; they must not capture raw user-authored content, direct identifiers, tokens, request bodies, response bodies, raw exception strings, schedule names, notes, place names, or preparation step names.

## Common Parameters

All events include:

| Parameter | Meaning |
| --- | --- |
| `schema_version` | Event schema version. First release uses `1`. |
| `workflow` | Product workflow that produced the event. |
| `result` | Stable result category such as `success`, `failure`, `allowed`, `denied`, or `disabled`. |
| `platform` | Coarse app platform. |
| `app_version` | App version string. |

Optional parameters must be allowlisted per event and limited to stable categories, coarse counts, or coarse durations.

## First-Release Events

| Event | Owner Question | Trigger Point | Allowed Parameters |
| --- | --- | --- | --- |
| `analytics_preference_changed` | How many users keep optional analytics enabled? | Analytics Preference update succeeds. | `enabled`, `source` |
| `onboarding_completed` | How many users complete first setup? | Onboarding use case succeeds. | `preparation_step_count`, `spare_time_minutes` |
| `sign_up_completed` | How many users create accounts successfully? | Sign-up succeeds. | `auth_provider` |
| `login_completed` | How many users return successfully? | Sign-in succeeds. | `auth_provider` |
| `schedule_create_started` | Where does schedule creation begin? | Schedule create form initializes. | `source` |
| `schedule_created` | How often do users create schedules? | Schedule creation succeeds. | `preparation_mode`, `preparation_step_count`, `minutes_until_schedule` |
| `schedule_updated` | How often do users revise schedules? | Schedule update succeeds. | `preparation_changed`, `minutes_until_schedule` |
| `schedule_deleted` | How often are schedules removed? | Schedule deletion succeeds at a BLoC or use-case workflow boundary. | `minutes_until_schedule` |
| `notification_permission_result` | How often do users grant notification access? | Notification permission flow resolves. | `permission_result`, `source` |
| `alarm_opened` | How often do alarms bring users into the preparation flow? | Alarm launch payload opens a schedule route. | `launch_action`, `provider` |
| `alarm_failed` | Which alarm failures need attention? | Alarm status/reporting detects a stable failure category. | `error_code`, `provider` |
| `schedule_finished` | How often do users finish preparation on time? | Schedule finish succeeds. | `lateness_bucket`, `preparation_step_count`, `started_early` |

## Forbidden Fields

Never include:

- Email, display name, OAuth identifier, FCM token, access token, or refresh token.
- Schedule name, schedule note, place name, or preparation step name.
- User-authored free text.
- Raw exception message, stack trace, request body, response body, or arbitrary map.
- Exact location data or any permission-sensitive data not already approved for analytics.

## Change Control

- Event names use stable snake_case.
- Breaking meaning changes require a new event name or `schema_version` increment.
- New events require an owner question and explicit allowed parameters before implementation.
- First-release failure tracking is limited to `alarm_failed`; other failure events require stable error categories before implementation.
- Marketing and personalization events are out of scope until deferred purposes are approved.
