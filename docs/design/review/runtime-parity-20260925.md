# Preparation runtime comparison — 2026-09-25

Canonical file `FIdR6bUMHScn9FWbwqrBsA`, Preparation page `1:21`. Fresh design contexts and screenshots were compared to real-font Flutter captures at Korean 390×844, top safe area44, fixed time and preparation data.

| Node | Source image | Flutter golden |
| --- | --- | --- |
| `118:2` | `docs/design/review/figma/runtime-on-time.png` | `test/goldens/goldens/runtime_on_time_390x844.png` |
| `118:58` | `docs/design/review/figma/runtime-late.png` | `test/goldens/goldens/runtime_late_390x844.png` |
| `118:114` | `docs/design/review/figma/runtime-finish-confirm.png` | `test/goldens/goldens/runtime_finish_confirm_390x844.png` |

The live timer uses the source268px circle at y121, 14px stroke, 28px preparation name, 48px countdown, top426px/bottom418px layout, blue/red timing colors, 358px preparation cards, 34px numbered badges and source checkmark artwork. Active cards135px, inactive62px, 14px connectors, 53px skip and57px finish actions match the reference geometry. Actual duration values, progress, scrolling and text scaling remain dynamic. Restoring an in-progress preparation now draws its saved ring progress immediately instead of starting at zero.

Manual finish now opens the explicit source confirmation. Cancel leaves the session running; only confirm dispatches the finish event. Lateness is recalculated at confirmation, and the existing persisted result flow is retained. Automatic all-steps-complete and continuing-until-departure behaviors are separately regression-tested.

A final independent review found that the last timer tick could open an automatic prompt over an already-open manual prompt. Both paths now reserve the same dialog slot and recheck the active schedule when the dialog closes. Continuing after the last step acknowledges completion without immediately reopening the automatic prompt; continuing before completion still allows the later automatic prompt. Two regressions use the real ScheduleBloc and a five-second last-step timer to prove both transitions. The final focused runtime group passes all 32 tests without changing the goldens.

## Explicit exceptions

- Figma's ring names “메이크업” while the active card names “샤워하기”, duplicates some step numbers and displays unrelated ring progress/countdowns. Flutter derives all names, numbers, durations and progress from the same active preparation state. The late fixture keeps real active-step remaining time rather than replacing it with a static overdue duration.
- Source confirmation promises Home navigation; the actual app shows the preparation result. Confirmation copy accurately describes that behavior. A functional44px Home close control is retained.
- Native status/home indicators are outside widget captures; bundled Pretendard replaces the Figma font. The dialog uses the viewport center while its text grows naturally.
- At320×640 and2× text, card content scrolls so the skip action stays reachable and the finish action remains anchored. Geometry from the fixed source is not enforced when it would clip accessible text.

## Verification

Five new tests cover three compared goldens, exact ring bounds, live remaining time, manual cancellation/confirmation, narrow enlarged-text skip/finish and restored initial progress. Twenty-five existing preparation flow tests cover early start, navigation, late/on-time completion, continuing timers and stale/missing schedules. All pass after the source changes; final combined validation is recorded in the completion report. The core backup checks run alongside this focused group are reported separately.
