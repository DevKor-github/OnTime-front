# iOS UI quality / Figma parity handoff

2026-09-24 checkpoint. The QA branch merged refreshed `main` commit `c7184b2a` in `64bc111d`. Source: OnTime Design System `FIdR6bUMHScn9FWbwqrBsA`, page `1:25`, board `285:5`. Korean iOS 390×844 is the main visual viewport; Calendar uses the 390×852 source where specified. The old `GiDCK...` link is not the source.

## Applied and verified

- `docs/design/figma_code_map.yaml` tracks 21 routes: four defaults reviewed, five in progress, seven pending, five excluded; 43 variants: 11 reviewed, 10 in progress, 22 pending. Each reviewed state has a source image hash and Flutter golden. `dart run tool/report_figma_ui_coverage.dart` validates the manifest; strict full coverage intentionally does not pass yet.
- My Page was rebuilt around the new recurring-entry frame `2113:21761`. Actual notification permission/settings, preparation/buffer values, backup/restore/reset routes, and English localization remain connected. A default golden and behavior/accessibility tests cover navigation, switches, and enlarged text.
- Recurring management list `2112:21676` and empty state `2112:21756` were compared with fresh Figma exports. List tests use two active and one ended series; goldens cover both layouts. Upstream create/detail/end-series behavior is retained and native detail navigation was smoke-tested.
- Calendar loading/error states have deterministic 390×852 goldens, fixed calendar card and retry-button geometry, blocked loading interactions, and retry tests. Home and Calendar default states remain in progress because Figma says December 2024 but draws November 2024 date positions. Flutter retains correct calendar arithmetic.
- The refreshed `main` changed recovery and reset confirmation into full screens, reset completion copy, and privacy layout. Tests and goldens were updated to the real code. Fresh Figma v3 exports show missing alert/info icons and spacing differences in recovery/confirmation, gutter differences in privacy, and wording/action differences in reset completion; their manifest statuses are in progress. The reset-complete button still explains a full app restart because storage is closed after reset.
- `flutter analyze --no-pub`, the local-only boundary check, Figma manifest check, and `git diff --check` pass. `flutter test --no-pub --coverage --concurrency=1` passed all 648 tests; the CI checker reports 86.08% coverage (11370/13209 app-owned lines, above the 80% minimum).
- The app built and launched on the `OnTime Recurring QA 20260923` iOS simulator (iOS 26.5, UUID `C8BA159D-A97A-458B-A5FC-B04A8B6F2848`). Native Home → My Page → recurring management → existing series detail → back succeeded. This does not establish backup/restore/reset, OS permission prompts, alarm delivery, performance, or physical-iPhone behavior.

## Remaining review

1. Review seven pending route defaults and 22 pending variants against current Figma exports. For each, preserve real product behavior, capture a deterministic golden, compare visibly, and update the manifest only after review.
2. Resolve the source's December-title/November-grid contradiction with product guidance; keep runtime dates correct meanwhile. Finish Home and Calendar visual review and native interaction flows.
3. Align Figma v3 recovery, confirmation, privacy, and reset-complete visuals where compatible with the closed-storage reset lifecycle. Recompare changed My Data password/restore dialogs after the shared modal-token refresh.
4. Execute native creation/edit/delete, backup/restore/reset, recovery, notifications/alarms, accessibility, and performance flows; an attached physical iPhone has not been profiled.

The original pre-merge WIP remains in `git stash@{0}` for safety; current tracked work incorporates the useful My Page, Calendar, and recurring changes. Do not apply that stash wholesale over the merged `main` screens.
