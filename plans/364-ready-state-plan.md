# Issue 364 Ready State Plan

## Goal
Make the alarm UI show an explicit ready/on-time state after every preparation step is complete, when the user chooses to keep the alarm screen open and the leave threshold has not yet passed.

## Context
- GitHub issue: https://github.com/DevKor-github/OnTime-front/issues/364
- Current alarm UI logic lives in `lib/presentation/alarm/screens/alarm_screen.dart`.
- `_buildAlarmScreen` currently sets `timerLabel` to `'지각이에요'` only for late-continue mode; otherwise it uses `preparation.currentStepName`.
- When all steps are done, the user has tapped continue, and the leave threshold has not passed, `displayRemainingSeconds` already uses `timeRemainingBeforeLeaving`, so only the center label still looks like an active preparation step.
- The completion dialog behavior should stay unchanged: completing all preparation steps shows the dialog but does not auto-finish the schedule.
- Late-continue behavior should stay unchanged once `timeRemainingBeforeLeaving.isNegative` becomes true.
- Localization sources live in `lib/l10n/app_en.arb` and `lib/l10n/app_ko.arb`; generated files live beside them.
- Existing widget coverage is concentrated in `test/presentation/alarm/screens/preparation_flow_widget_test.dart`.

## Decisions
- Add a new localization key for the ready-state label rather than hard-coding copy in `AlarmScreen`.
- Use `Ready to go` for English.
- Use `출발 준비 완료` for Korean unless product/design requests different final wording.
- Keep the current blue/on-time theme and progress behavior for all-done, continuing, not-late state.
- Keep the red late-continue theme, zero graph progress, overdue countdown, and late label after the leave threshold.

## Steps
1. Add a ready-state localization key to `lib/l10n/app_en.arb` and `lib/l10n/app_ko.arb`, including an English description in the template ARB.
2. Regenerate localization outputs with Flutter gen-l10n so `app_localizations.dart`, `app_localizations_en.dart`, and `app_localizations_ko.dart` expose the new getter.
3. In `AlarmScreen._buildAlarmScreen`, derive three readable booleans:
   - `isContinuingAfterCompletion = preparation.isAllStepsDone && _isContinuingAfterCompletion`
   - `isLateContinueMode = isContinuingAfterCompletion && isLate`
   - `isReadyContinueMode = isContinuingAfterCompletion && !isLate`
4. Set `timerLabel` to:
   - `l10n.lateContinueLabel` or the existing late copy key if one is introduced for the current hard-coded `'지각이에요'`
   - `l10n.preparationReadyToGo` for ready-continue mode
   - `preparation.currentStepName` for normal active-step mode
5. Preserve the current `displayRemainingSeconds` behavior so both ready-continue and late-continue modes use `timeRemainingBeforeLeaving.inSeconds.abs()`, while active preparation still uses `preparation.currentStepRemainingTime`.
6. Update `completion dialog continue shows live leave countdown for ongoing flow` to assert the ready label is visible and the final step name is no longer used as the center timer label in the ready-continue state.
7. Update or keep `completion dialog continue keeps overdue timer running after leave time` to assert the late label still appears after crossing the threshold, the overdue countdown remains visible, and the step list can still show the completed step name.
8. Add Korean-ready-label expectations only where the test locale is Korean; if the test harness defaults to Korean, assert `출발 준비 완료`. If an English-locale path is easy to set up in the existing helpers, add a small English assertion for `Ready to go`.

## Validation
- `flutter gen-l10n`
- `dart format lib/l10n lib/presentation/alarm/screens/alarm_screen.dart test/presentation/alarm/screens/preparation_flow_widget_test.dart`
- `flutter test test/presentation/alarm/screens/preparation_flow_widget_test.dart`
- `flutter analyze`

## Open Questions
- Confirm whether `출발 준비 완료` is the final Korean copy. It is a safe implementation default because it is short, explicit, and clearly distinct from both an active preparation step and a late state.
