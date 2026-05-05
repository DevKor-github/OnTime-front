# Issue 363 Alarm No-Schedule Fallback Plan

## Goal
Ensure `/alarmScreen` navigates back to `/home` when it is opened while `ScheduleBloc.state.status` is already `ScheduleStatus.notExists`, instead of leaving the user on the loading spinner.

Issue: https://github.com/DevKor-github/OnTime-front/issues/363

## Context
- The issue covers stale notification, deleted schedule, and already-ended schedule entry paths.
- `AlarmScreen` currently handles transitions into `notExists` in `lib/presentation/alarm/screens/alarm_screen.dart`, but its `BlocListener.listenWhen` only fires when the previous status was not `notExists`.
- When the alarm route is built with an already-`notExists` state, no listener event fires and the `BlocBuilder` falls through to the loading scaffold.
- Finish flow uses `_navigateAfterFinish`, `_pendingEarlyLateSeconds`, and `_pendingIsLate` to route to `/earlyLate` after `ScheduleFinished` emits `notExists`; this path must remain higher priority than the home fallback.
- Existing alarm widget coverage lives in `test/presentation/alarm/screens/preparation_flow_widget_test.dart`.

## Decisions
- Treat an already-`notExists` state on alarm route entry as terminal for `/alarmScreen`.
- Trigger the fallback with a post-frame callback, because navigation should not happen synchronously during build.
- Keep the existing transition listener for active schedule flows that later become `notExists`.
- Preserve `_navigateAfterFinish` handling so manual or dialog finish still routes to `/earlyLate`.
- Scope the implementation to `AlarmScreen` and alarm widget tests; no bloc behavior change is needed.

## Steps
1. In `AlarmScreen`, add a helper such as `_navigateHomeAfterFrameIfMounted(BuildContext context)` to centralize safe post-frame home navigation.
2. In the `BlocBuilder` branch for `ScheduleStatus.notExists`, check that `_navigateAfterFinish` is false, clear transient alarm UI state, stop the UI ticker, and schedule the home navigation after the current frame.
3. Leave the current `BlocListener` in place for `ongoing`, `started`, or `upcoming` states that later emit `notExists`.
4. Make sure the loading scaffold remains only for genuinely unresolved statuses, especially `ScheduleStatus.initial`.
5. Add a widget test that seeds the alarm bloc with `const ScheduleState.notExists()` before pumping `/alarmScreen`, then expects `/home`.
6. Add a stale-notification-style widget test with a stream that emits `null` while the bloc is already `notExists`, then confirms `/home` and no finish-use-case call.
7. Re-run existing finish navigation tests, especially manual finish and completion dialog finish cases, to confirm `/earlyLate` remains the result when `_navigateAfterFinish` is pending.

## Validation
- `flutter test test/presentation/alarm/screens/preparation_flow_widget_test.dart`
- `flutter analyze`

## Open Questions
- None.
