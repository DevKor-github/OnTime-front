# Onboarding and notification permission review — 2026-09-25

The canonical source is Figma `FIdR6bUMHScn9FWbwqrBsA`, page `1:23`, Onboarding/FlowScreens and Permission/NotificationPermission families. These active app surfaces must not be excluded merely because they are absent from board `285:5`. Every node below was read with fresh design context and screenshot.

## Sources and captures

| Node | State | Source image | SHA-256 | Flutter golden |
| --- | --- | --- | --- | --- |
| `246:42` | welcome | `docs/design/review/figma/onboarding-0-20260925.png` | `b4e365b2ebe04c028c77f6b47af4d71cd1eaf3601e67ef427652e6614f167a2d` | `test/goldens/goldens/onboarding_welcome_390x844.png` |
| `246:53` | select | `docs/design/review/figma/onboarding-1-20260925.png` | `a7cbab4c426baf609e2ce0b919a415cece70d0387199a1260e82ce1c8352c6d4` | `test/goldens/goldens/onboarding_select_390x844.png` |
| `246:90` | add | `docs/design/review/figma/onboarding-2-20260925.png` | `51f0d329717347fd0df91b6b6756fa40112c2809da65511fb1fe688d4522d1c1` | `test/goldens/goldens/onboarding_add_390x844.png` |
| `246:113` | selected | `docs/design/review/figma/onboarding-3-20260925.png` | `d89d8e494229a0e62ed43054028b7f1a46ac23017cc646dac83088456e18cdca` | `test/goldens/goldens/onboarding_selected_390x844.png` |
| `246:150` | order | `docs/design/review/figma/onboarding-4-20260925.png` | `79514dd77bc8bcf081cf8dfd3e813baf92e256c00715fdba94c85d2a26055f81` | `test/goldens/goldens/onboarding_order_390x844.png` |
| `246:180` | time | `docs/design/review/figma/onboarding-5-20260925.png` | `681613261674d17d72260f67bc17f63574bebe11ac3bf9b8747d190b84fbc489` | `test/goldens/goldens/onboarding_time_390x844.png` |
| `246:212` | buffer | `docs/design/review/figma/onboarding-6-20260925.png` | `0b148e6e8b357f3b41e298e508148176b183a7956b3acfc7b7135a242d81ed87` | `test/goldens/goldens/onboarding_buffer_390x844.png` |
| `278:100` | time_focused | `docs/design/review/figma/onboarding-7-20260925.png` | `389a73aa5b3fc1a3efec3077fd94695009a2f5ce5d00ec14469614a377bed3a8` | `test/goldens/goldens/onboarding_time_focused_390x844.png` |
| `278:187` | time_short | `docs/design/review/figma/onboarding-8-20260925.png` | `9a9ec8a31e93b79045623e66c7a01622bde52dcd0ddc89b15b2dd9ce3df7390b` | `test/goldens/goldens/onboarding_time_short_390x844.png` |
| `278:274` | time_long | `docs/design/review/figma/onboarding-9-20260925.png` | `bdceb130364cf9a585bc47426462460e408f24319290c131dfbce0b5637d9222` | `test/goldens/goldens/onboarding_time_long_390x844.png` |
| `246:230` | notification_permission | `docs/design/review/figma/onboarding-10-20260925.png` | `ceba9ea9bb5429e33ac8bd38332f90c93ca65878c60ae3d707e8a12a3e2e1b5e` | `test/goldens/goldens/notification_permission_390x844.png` |
| `246:238` | system_prompt | `docs/design/review/figma/onboarding-11-20260925.png` | `12bd9bd4f0c706eb1ac9de5202595e20aa746ace1ee4bc84bf98743fa1565d2d` | `OS-owned system prompt; gateway behavior tested` |

## Changes

- The welcome screen uses the exact downloaded greeting image, 271×280 at the source position, and a 358×58 primary action at (16,752). The content scrolls at narrower widths/larger text.
- The existing four-step setup now uses the source Korean headings, single-line STEP labels, exact source progress segments, five editable preparation suggestions, 62px selection/reorder rows, and matching primary colors. The flow remains entirely local.
- Time entry now uses an actual numeric TextFormField and platform keyboard, matching the interaction in the Figma TimeInput family. The existing Formz domain validation still rejects zero/negative/over-1440-minute durations. Fields preserve controller selection while editing and update when the cubit changes externally. The total is derived from entered durations and inherits the real app font. Tapping anywhere on a duration row focuses the field and selects its value, including the row-wide accessibility bounds reported by iOS. The unit and accessibility label use the active localization.
- The notification request uses the exact 36×37 bell SVG inside a 70px badge, 358×58 primary action with an 8px radius, and a real TextButton for the defer action. Permission results, denial, deferral, settings resume and home navigation retain the existing gateway/cubit behavior.

## Documented exceptions

- Native status bars, home indicators, numeric/alphabetic keyboards, and the iOS permission alert are OS-owned. Widget goldens model keyboard insets and focus but do not draw a fake system keyboard or permission prompt. `246:238` is excluded only as a platform overlay; the app-owned request behind it is reviewed against `246:230`.
- The source time input screenshots show “총 시간: 30분” even when displayed values sum to 0, 60, 40, or 100030. Flutter calculates the real sum and prevents submitting 100000 minutes. The mockup’s oversized value is an invalid-input fixture, not permission to weaken the domain limit.
- Figma shows an enabled Next action with zero preparation selections. Flutter keeps it disabled until at least one valid preparation is selected.
- The default spare time remains the current product value 30 minutes. The source 10-minute state is reproduced with a valid 10-minute fixture. The existing minimum-decrease warning is visible at the minimum; the Figma buffer frame omits this current product warning.
- Notification rationale preserves the product’s precise schedule-preparation reminder copy (“약속 준비 리마인더를 보내…”), which explains actual local-notification use. It does not revert to the older generic promise in Figma.
- The current app uses bundled Pretendard; Figma uses Noto Sans KR/IBM Plex Sans KR. Text metrics vary. STEP labels remain compact while their semantic label announces the active step; form copy, controls and input text scale normally.
- App content can scroll and grows with text. An added preparation field scrolls into view based on the actual keyboard/focus geometry; the Figma AddPreparation frame freezes a particular scroll offset. The selection form retains the same vertical position when selections change, while the source SelectedPreparation variant shifts its first row down 22px. The app avoids moving all rows when the user selects a choice.
- Notification defer retains a 44px touch target, which shifts the footer content 4px relative to the smaller source text target. Numeric inputs retain a real caret, focus underline, and platform text editing. Long invalid input expands to fit Pretendard digits rather than clipping to the mockup width.

## Assets

All files below are nonempty original Figma downloads. SVG root sizes are used at callsites without modification. The greeting image is precached before visual capture so missing asynchronous raster decoding cannot be accepted as a blank golden.

- `assets/design/onboarding_drag.svg` — SHA-256 `ad38a92436c5b8aad4e799b8436f1d2560cce14091039065a86e6753c4393508`
- `assets/design/onboarding_greeting.png` — SHA-256 `b37032dbcde924bf5f054a06c105efe884d8ccef787274e6c5648dd0e46d8c64`
- `assets/design/onboarding_progress_complete.svg` — SHA-256 `9771c7f3860d3f95d9fb95b2d359f071aab7da254cbdd860b2abdeca00dd9247`
- `assets/design/onboarding_progress_current.svg` — SHA-256 `7ff87b51206a3f1c5a9bb5aafd71a68b179aef5095e215b9a9c73ee47d93386d`
- `assets/design/onboarding_progress_last_current.svg` — SHA-256 `c5281905e24fc557df43aef4e3f55767597a875d3f9466c1ea92f4cf2ca18f45`
- `assets/design/onboarding_progress_last_pending.svg` — SHA-256 `329c31f798bace191fea4bcf6044c812a023ea9e8197625ec9a6084b15cd15dd`
- `assets/design/onboarding_progress_pending.svg` — SHA-256 `8c43a3af95906abc736c744e41de6708a20456f928ee6354b59c4cc24da4cf7c`
- `assets/design/notification_bell.svg` — SHA-256 `cda453a5be09d508d0287b623ad140dd1c298d7211fb1283b0efba3fe100ac2d`

## Verification

New tests cover the welcome image/action geometry; initial selection validation; selecting, adding and editing six preparations; reorder persistence; numeric focus/short/oversized entry; computed totals; invalid submission prevention; valid duration persistence; 320px/2× text; and notification request golden/iOS touch and label checks. Existing tests cover local profile submission/failure and every notification gateway result. The three-file focused run completed with **17 tests passed** (`/private/tmp/ontime-onboarding-final2-test.log`). The final five visual tests, including the added row-center tap → focus and full-selection regression, passed after the font and drag-size refinements (`/private/tmp/ontime-onboarding-final3-test.log`). A five-test non-update golden run also passed before the final invalid-input width adjustment; the parent task owns the final full-suite verification.

The parent task independently rebuilt the iOS app and confirmed row-wide tap, entry of 3 minutes, and onboarding save on the simulator after this change. This is simulator evidence, not physical-device evidence.

Final visual assessment: all 11 app-owned states have source-backed captures and are reviewed with the explicit behavior, typography, and OS exceptions above. The greeting raster, progress segments, row styling, drag icon, bell, actions, recovery-related states and totals render correctly. This is not a claim of pixel-identical Figma fonts or fake native keyboards. No unresolved app-owned icon or clipping defect is accepted as a passing golden.
