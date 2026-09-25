# Home · Calendar Figma comparison — 2026-09-25

Canonical file: `FIdR6bUMHScn9FWbwqrBsA`. Fresh `get_design_context` and screenshots were read for Home Default/Loading/Error and Calendar Expanded/List/SwipeActions/ExpandedActions/DeleteConfirm. Calendar's shared month/card components were inspected through these full-fidelity contexts. Existing Empty/Loading/Error source PNGs are retained.

## Compared states

| State | Figma node | Source image | Flutter golden | Source SHA-256 |
|---|---|---|---|---|
| Home default | `600:34301` | `figma/home-default.png` | `home_default_390x844.png` | `87d9c1e3ed1a5a556f2fbb8081abaacdbeb41fbbf19f4d1cf998e015fac70d40` |
| Home loading | `1824:2` | `figma/home-loading.png` | `home_loading_390x844.png` | `52362c7a344d8e4cf788b4ce9ac5bb89631e813a3a7f7e08ce9eb80cf041c6a7` |
| Home error | `1824:694` | `figma/home-error.png` | `home_error_390x844.png` | `7aa8f80ce1ff05847209828f49045bc8e1d0a09803fd1625534860ff4d746281` |
| Calendar empty | `868:146599` | `figma/calendar-empty.png` | `calendar_empty_390x852.png` | `0a1bd7f2eb3afcc6c6809c8d9f7d05a904fcfcde6f13570188a97cc9bf242e8b` |
| Calendar expanded | `868:146600` | `figma/calendar-expanded.png` | `calendar_expanded_390x852.png` | `1583f6db767d15b1a7aea64dac8f51dba795d9c8d64339baeb42d6f747bae69d` |
| Calendar list | `882:426235` | `figma/calendar-list.png` | `calendar_list_390x852.png` | `422d779410182dec6a1c5050d3b9c76c4a4de0116c16c946d0bfd400a091e3da` |
| Calendar swipe actions | `882:464741` | `figma/calendar-swipe-actions.png` | `calendar_swipe_actions_390x852.png` | `f9687add5e58cad41b146a3a448fe67e402a471d3b8d83277440be05e6983fee` |
| Calendar expanded actions | `882:493347` | `figma/calendar-expanded-actions.png` | `calendar_expanded_actions_390x852.png` | `b475c56020d23f555bb07c44bf7dc3e201ffa170ef9473eccdf27ba370ec6aec` |
| Calendar delete confirmation | `882:512625` | `figma/calendar-delete-confirm.png` | `calendar_delete_confirm_390x852.png` | `a00d9ca5a8ad5a693f59da83cdfbcf72e8b34095fc9c101cc9aba9c4f77091c0` |
| Calendar loading | `1816:6728` | `figma/calendar-loading.png` | `calendar_loading_390x852.png` | `d96b113898d510c8e11a391d6dc2f05a8671680a6986ef989464f297556a2be7` |
| Calendar error | `1816:6984` | `figma/calendar-error.png` | `calendar_error_390x852.png` | `a7d69eddcc876d99622541c561c0c81b55f24a3344af7bd72a505b34bd12f540` |

Source paths are relative to this directory. Goldens are under `test/goldens/goldens/`.

## Changes and visual assessment

- Home preserves the 230px hero, 360×137 today card at (15,177), 360×391 month card, and 76px add action. Bottom navigation matches the 81px source height and icon centers (80,310). Home's today-card shadow is painted above the following month surface and golden capture includes normal Flutter shadows.
- Compact Calendar month cells use 51px rows instead of 44px plus a large bottom gutter. Selected date uses a 40px circle and numeric day (no Korean `일` suffix). The source month card is (18,110,354,390); the selected-date heading/card stack is aligned with source y532/y592.
- Schedule cards use 82px collapsed and 192px expanded height, a 70px time column/divider, 21px content inset, and 16px row gaps. Dynamic appointment times use 12-hour notation because a separate AM/PM label is visible.
- Swipe actions use 82px source buttons, 8px collapsed/10px expanded gaps, exact source `#545454` edit / `#bf2e22` delete colors, and rounded viewport clipping. Source SVGs are local `assets/calendar_chevron_down.svg` (24×25), `calendar_map_pin.svg` (18×19), `calendar_edit.svg` (24×24), `calendar_trash.svg` (24×24). Header/month arrows and Home navigation also use local exact source SVGs (`calendar_back.svg`/`calendar_month_arrow.svg` 24×24; `home_nav_home.svg`/`home_nav_my.svg` 24×24; `home_nav_add.svg` 50×50). Each is nonempty and rendered at its root geometry; the map pin has an explicit 18×19 slot.
- Delete confirmation retains the revealed schedule/actions behind a 42% scrim, uses the existing 277px dialog with 16px padding and 12px gaps, and centers across the full viewport. Cancelling does not delete data. The configurable shared-dialog additions preserve default behavior for other call sites.
- Card content grows at enlarged text sizes rather than enforcing the source's fixed heights. Existing edit restrictions for past/preparing/early-started/completed schedules and recurring occurrence controls remain intact.

## Explicit source exceptions

These states can be recorded as reviewed with the following exceptions; they are not an assertion of pixel identity:

1. **Calendar truth:** Figma labels the month December 2024 but its grid is November 2024 (day 1 on Friday; day 21 on Thursday). Actual December 2024 begins Sunday and day 21 is Saturday. Both Home and Calendar deliberately render real dates; weekday positions and marker positions therefore differ. This is a documented source inconsistency, not an unresolved request to hard-code an incorrect calendar.
2. **Fixture data:** Figma appointment cards contain placeholders (`시간`, `-시간--분`, `--분`). The deterministic Flutter fixture contains real 6:00/7:00 PM appointments, 80-minute travel, loaded 0-minute preparation, and 10-minute buffer. Data text is not replaced by source placeholder strings.
3. **Typography/system UI:** The app bundles Pretendard, while these source nodes use Noto Sans KR/IBM Plex Sans KR. Glyph metrics and small text offsets differ. Native status bar and home indicator are platform-owned and excluded. Source loading/error exports also clip the selected-date heading; Flutter retains the complete heading.

## Unmapped full Schedule Detail design audit

The newly discovered `ScreenShell/ScheduleDetail` nodes are a separate full-screen design, not `lib/presentation/calendar/component/schedule_detail.dart`. Fresh context/screenshot for Upcoming (`1756:8930`) shows a standalone header, event facts, four-stage timing timeline, preparation plan, and start action. Repository route/code search finds no matching schedule-detail route or full-screen implementation; the similarly named Flutter component is only a Calendar expandable card.

Unmapped full-screen states: Upcoming `1756:8930`; PreparationDue `1775:9192`; Preparing `1775:9197`; CompletedOnTime `1775:9202`; CompletedLate `1775:9207`; CompletedUnknown `1775:9212`; PastUnrecorded `1775:9217`; Loading `1913:11757`; Refreshing `1913:12081`; NotFound `1913:11857`; Failure `1913:11969`. These must remain explicitly unmapped, not count as passed Calendar variants. Adding that product flow requires separate route/state implementation.

## Verification

Final source/Flutter screenshots were visually inspected after rendering. Focused Home/Calendar/shared-dialog/calendar-theme run: 105 tests, 103 passed initially; a standalone 2x test fixture was corrected to use the real scrollable card context and the marker-color assertion was updated to the Figma token. Both affected files were rerun: all 13 tests passed. The root full suite remains the final combined gate. Existing coverage includes real date selection/month arrows, loading/error retry, create refresh, delete failure, back navigation, edit/delete lifecycle guards, recurring controls, and compact/enlarged-text layout. Five new source-state goldens cover list/expanded/swipe/expanded-actions/delete confirmation; the delete capture asserts no deletion occurs before confirmation and cancellation leaves data intact.
