# Issue 535 Use Case Classification

Issue #535 asks for a deletion-test audit of `lib/domain/use-cases/`. This
plan classifies every current use case as of this branch and records the
remaining consolidation work after the schedule preparation session slice.

## Classification Key

- **Keep**: hides workflow policy, orchestration, reconciliation, date/range
  semantics, cleanup, or approved event semantics.
- **Deepen**: useful workflow boundary, but should absorb more adjacent shallow
  operations before being considered done.
- **Consolidate**: shallow pass-through or one step in a larger workflow; keep
  only until callers move to the deeper workflow.
- **Delete**: remove after callers and tests no longer need the wrapper.

## Current Use Cases

| Use case | Classification | Notes |
| --- | --- | --- |
| `cancel_all_alarms_use_case.dart` | Keep | Multi-provider cleanup plus device unregister policy. |
| `cancel_schedule_alarm_use_case.dart` | Keep | Idempotent native/fallback cancellation and registry cleanup. |
| `clear_early_start_session_use_case.dart` | Delete | Folded into `SchedulePreparationSessionUseCase.clearPersistedState`. |
| `clear_timed_preparation_use_case.dart` | Delete | Folded into `SchedulePreparationSessionUseCase.clearPersistedState`. |
| `create_custom_preparation_use_case.dart` | Consolidate | Part of preparation/template authoring workflow. |
| `create_preparation_template_use_case.dart` | Consolidate | Part of preparation template CRUD workflow. |
| `create_schedule_with_place_use_case.dart` | Keep | Schedule mutation plus alarm reconciliation. |
| `delete_preparation_template_use_case.dart` | Consolidate | Part of preparation template CRUD workflow. |
| `delete_schedule_use_case.dart` | Keep | Schedule deletion, scheduled delivery cleanup, reconciliation. |
| `delete_user_use_case.dart` | Keep | Account deletion workflow boundary. |
| `finish_schedule_use_case.dart` | Delete | Folded into `SchedulePreparationSessionUseCase.finishSchedulePreparation` for `ScheduleBloc`; remove after other callers migrate. |
| `get_adjacent_schedules_with_preparation_use_case.dart` | Keep | Date-adjacent schedule/preparation composition. |
| `get_default_preparation_use_case.dart` | Consolidate | Part of default preparation workflow. |
| `get_early_start_session_use_case.dart` | Delete | Folded into `SchedulePreparationSessionUseCase.hasEarlyStartSession`. |
| `get_nearest_upcoming_schedule_use_case.dart` | Keep | Upcoming schedule selection and preparation loading semantics. |
| `get_preparation_by_schedule_id_use_case.dart` | Consolidate | Cache read step in schedule/preparation loading workflows. |
| `get_preparation_template_use_case.dart` | Consolidate | Part of preparation template workflow. |
| `get_preparation_templates_use_case.dart` | Consolidate | Part of preparation template workflow. |
| `get_schedule_by_id_use_case.dart` | Consolidate | Retrieval step in prompt/form workflows. |
| `get_schedules_by_date_use_case.dart` | Consolidate | Lower-level schedule calendar read step. |
| `get_timed_preparation_snapshot_use_case.dart` | Delete | Folded into `SchedulePreparationSessionUseCase.restoreTimedPreparationIfValid`. |
| `load_adjacent_schedule_with_preparation_use_case.dart` | Keep | Coordinates date-range loading with preparation prefetch. |
| `load_analytics_preference_use_case.dart` | Keep | Account/install preference loading boundary. |
| `load_preparation_by_schedule_id_use_case.dart` | Consolidate | Cache refresh step in schedule/preparation loading workflows. |
| `load_schedules_by_date_use_case.dart` | Consolidate | Lower-level schedule calendar loading step. |
| `load_schedules_for_month_use_case.dart` | Consolidate | Calendar workflow candidate with date-range semantics. |
| `load_schedules_for_week_use_case.dart` | Consolidate | Calendar workflow candidate with date-range semantics. |
| `load_user_use_case.dart` | Consolidate | Shallow user repository stream/read wrapper. |
| `mark_early_start_session_use_case.dart` | Delete | Folded into `SchedulePreparationSessionUseCase.startEarlySession`. |
| `onboard_use_case.dart` | Keep | Onboarding completion workflow. |
| `reconcile_alarms_use_case.dart` | Keep | Deep schedule delivery reconciliation workflow. |
| `save_timed_preparation_use_case.dart` | Delete | Folded into `SchedulePreparationSessionUseCase.saveTimedPreparationSnapshot`. |
| `schedule_preparation_session_use_case.dart` | Deepen | New workflow boundary for active preparation session behavior. |
| `sign_out_use_case.dart` | Keep | Sign-out cleanup ordering. |
| `start_schedule_use_case.dart` | Delete | Folded into `SchedulePreparationSessionUseCase.startSchedulePreparation`. |
| `stream_preparations_use_case.dart` | Consolidate | Lower-level preparation cache stream wrapper. |
| `stream_user_use_case.dart` | Consolidate | Shallow user repository stream wrapper. |
| `track_product_usage_event_use_case.dart` | Keep | Approved analytics event boundary. |
| `update_analytics_preference_use_case.dart` | Keep | Preference mutation plus persistence boundary. |
| `update_default_preparation_use_case.dart` | Consolidate | Part of default preparation workflow. |
| `update_preparation_by_schedule_id_use_case.dart` | Consolidate | Part of schedule-specific preparation workflow. |
| `update_preparation_template_use_case.dart` | Consolidate | Part of preparation template workflow. |
| `update_schedule_use_case.dart` | Keep | Schedule mutation plus alarm reconciliation. |
| `update_spare_time_use_case.dart` | Consolidate | Part of default preparation workflow. |

## Slice Completed In This Branch

- Introduce `SchedulePreparationSessionUseCase` for early starts, session start
  dedupe, timed-preparation snapshot save/restore/clear, alarm prompt
  validation, and session finish cleanup.
- Reduce `ScheduleBloc` constructor dependencies from separate session,
  snapshot, prompt-loading, start, finish, and alarm cleanup use cases to one
  workflow dependency.
- Keep UI-owned timer, navigation, and step-notification behavior inside
  `ScheduleBloc`.

## Remaining Checklist

- Migrate any non-`ScheduleBloc` callers off the deleted-category wrappers.
- Delete the obsolete shallow wrappers once caller migration is complete.
- Consolidate preparation/template CRUD into one workflow-level use case.
- Consolidate calendar date/week/month loading into one calendar workflow
  boundary.
- Revisit user stream/load wrappers after auth/account workflows are clarified.
