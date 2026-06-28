# Preparation Run Action Events Plan

## Goal

Fix preparation timer drift after sleep or app suspension by making local preparation progress derive from a Preparation Run start time and user-performed Preparation Action Events instead of persisted elapsed-time snapshots.

## Confirmed Decisions

- A Preparation Action Event records user actions only: start, skip step, and finish.
- Automatic step transitions are derived states, not stored events.
- The Preparation Run start event time is the timing source for preparation progress.
- Skip ends the current step at the skip time and does not treat unused planned duration as elapsed.
- The first implementation is local app state only; backend start and finish calls stay as they are.
- Finish clears the local Preparation Run only after server finish succeeds.
- Deleting a schedule must clear the local Preparation Run.
- Schedule fingerprint mismatch invalidates the stored Preparation Run.

## TDD Order

1. RED: restoring an ongoing run derives the current step from start time, skip event, and current time.
2. GREEN: add the smallest local run/action-event model and derivation path needed for that behavior.
3. RED: sleep/wake or delayed tick refresh derives elapsed from actual current time rather than adding one second.
4. GREEN: add a public refresh/resume path through `ScheduleBloc`.
5. RED: schedule deletion clears the local Preparation Run.
6. GREEN: wire delete flow to clear the run.

## Validation

- Run targeted `flutter test test/presentation/app/bloc/schedule/schedule_bloc_test.dart`.
- Add narrower data-source/use-case tests only when persistence behavior cannot be verified through `ScheduleBloc`.
- Run `flutter analyze` after the implementation stabilizes.
