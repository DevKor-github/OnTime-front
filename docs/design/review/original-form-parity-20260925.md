# Original appointment forms and preparation editing — 2026-09-25

Canonical Figma file: `FIdR6bUMHScn9FWbwqrBsA`, page `1:26`. Fresh design context and screenshots were read for all five nodes before changing the implementation. The source exports below are stored at 390×844. Flutter captures use the real production widgets and bundled Pretendard fonts.

| State | Figma node | Source PNG | Flutter golden | Source SHA-256 |
|---|---|---|---|---|
| Name input | `251:42` | `figma/form-name.png` | `form_name_390x844.png` | `912f174f618dfd88e6bdec1ad0f1aca2ae403377e51fcbb9ddb234c8f6642965` |
| Date picker | `251:75` | `figma/form-date.png` | `form_date_picker_390x844.png` | `147cc7d396469cb4e11af53b1dca3c25c1d7da57cf75c2e5a315143eb6bdb616` |
| Time picker | `251:119` | `figma/form-time.png` | `form_time_picker_390x844.png` | `50aacc58ce78d7ed1c2e1ccb027260cf1cca8e7e17bd1e8e2f17feb638b64995` |
| Place and travel input | `251:162` | `figma/form-place.png` | `form_place_390x844.png` | `2bb089c948342412305999ccc5303fecf43c751b3ccd0dcd7caa88acfd40996e` |
| Preparation edit | `1334:2023` | `figma/form-preparation.png` | `preparation_edit_390x844.png` | `0ea7a3def11759115f924c88cc93b9f4176c52a09a40876c4d2bd4ded1f30684` |

Source paths are relative to this report; Flutter goldens are under `test/goldens/goldens/`.

## Implementation and comparison

- Name and place captures open `KeyboardBackedBottomSheet` through the same `showModalBottomSheet` options used by production, then render/navigate the actual `ScheduleMultiPageForm`. They cover the empty name and empty place/zero travel state. The static bloc isolates rendering; existing form widget/domain tests cover validation and save behavior.
- The shared date/time/minute picker sheet now follows the source structure: 16px horizontal padding, 24px top/section gaps, 167px native wheel viewport, 16px top corners, 42% scrim, and paired source-color cancel/input buttons. Date/time/minute values still come from native Cupertino widgets. Save commits the current value; cancellation only dismisses. The minute scroll controller is disposed after the modal completes.
- Preparation editing now has a meaningful localized header and Done action, a computed total duration, 16px horizontal content insets, and list start at y167. Four rows retain the source 62px height and 8px separation at default text scale. The source drag icon is stored as `assets/preparation_edit_drag.svg` (18×16, SHA-256 `5755366e0fe2044409763c277fea35bd8fd2d8f55084bdac3b0ce4596885fc48`). Duration chips grow with text scale and show localized minute units. The existing draft/save/reorder interactions remain in place.
- The 10+10+5+5 minute fixture displays a real 30-minute total. Editing the first step and pressing Done updates `PreparationEditDraftCubit`; the same save remains reachable at 2× text scale.

## Explicit source exceptions

These five states are reviewed with exceptions, not pixel-identical renders:

1. **Current shared form flow:** The original name/place/date/time Figma nodes contain an 80% sheet, `STEP 1–4` labels, and a top-right Next action. Current production and the newer recurring design use an 85% sheet, Korean descriptive step labels, and bottom Back/Next actions. That current shared flow is preserved; old source frames do not justify reverting the newer recurring implementation. Name/place content remains the actual editable fields, including useful name placeholder and the real `0시간 0분` value. Source empty placeholders are not application data.
2. **Native picker rendering:** Figma contains flat numeric wheel artwork, while Flutter retains accessible, localized Cupertino wheels, including Korean year/month/day and AM/PM labels, native perspective, and selection behavior. The Figma sheet starts at y532 but its declared 333px content extends 21px beyond the 844px frame. Flutter keeps the entire sheet and bottom controls visible, so its top is y513. The isolated date/time golden's host above the modal is only a test trigger; comparison is the picker sheet region, not that host. The app's actual date/time field integration is covered separately by `schedule_date_time_form_test.dart`.
3. **Typography:** Source uses Noto Sans KR/IBM Plex Sans KR; the app uses Pretendard. The golden harness explicitly substitutes Pretendard for unavailable private Cupertino SF fonts. Production keeps the native Cupertino font choice. Native system chrome is excluded.
4. **Preparation source content:** The Figma header says “캘린더” and shows four `00 분` placeholders beside a 30-minute total. Production uses “준비 과정 및 시간 수정” and the actual sum of actual step durations. This is a source text/arithmetic inconsistency, not an application mismatch to copy. The existing add control retains its 44px accessible tap area around a 32px circle; its center is 4px above the source artwork.

## Verification

`test/presentation/schedule_create/original_form_visual_test.dart` adds five PNG captures and six behavior/visual tests: name/place navigation, native date/time save, 2× picker cancellation without save, and preparation edit/draft save at 2×. The rendered PNGs were opened and visually compared with fresh Figma exports; this check caught and corrected the source SVG package-path issue.

Focused original-form/picker/preparation/date/place run: 28 tests, initially 27 passed. The one failure was an existing Korean date-format assertion after the recurring design changed formatting to include weekday (`2026년 5월 15일 (금)`); the expectation was updated and all three date-time tests passed on rerun. The original-form and preparation-row rerun passed all 12 tests. After the SVG package-path correction, all six original-form tests passed again and the final preparation-edit image was inspected with the source drag icons visible. Coverage includes minute-wheel movement/save/disposal, cancel without save, timer/date initial selection save, field validation, focus identity changes, add-row picker lifecycle, reorder, and date/time cubit wiring. The root full-suite run remains the combined regression gate.

No native-device picker or accessibility-screen-reader claim is made by these widget/golden checks.

### Shared six-row editor regression review

The root full-suite run exposed a 1.75% difference in the existing `preparation_spare_time_edit_390x844.png`. Comparing its test/master/diff images against `figma/preparation-spare-time-edit-default.png` (node `600:35201`) isolated the difference to the new source 18×16 drag SVG and the resulting slight name-position shift. Duration chips, row geometry, and actions were unchanged; the fresh icon and name position are closer to the source. The single affected golden was therefore updated with this evidence. All eight tests in `preparation_spare_time_edit_screen_test.dart` passed, including edit persistence during spare-time changes, save failure, asynchronous save completion, changed-duration submission, six-row geometry, and adding a seventh step.
