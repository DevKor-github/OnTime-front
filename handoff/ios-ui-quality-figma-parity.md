# iOS UI quality / Figma parity handoff

2026-09-23 checkpoint. Branch: `codex/ios-ui-quality-figma-parity`, based on committed `feature/figma-offline-screen-sync` commit `44067d7ab26b6290c16cdb13b99f57387dec08f6`. This isolated worktree did not copy changes from other worktrees.

Source Figma file: `FIdR6bUMHScn9FWbwqrBsA` (`OnTime-Design-System`), page `1:25`, board `285:5`. The old `GiDCK...` link is not the review source. Reference viewport: Korean iOS 390×844.

## Current result

- `docs/design/figma_code_map.yaml` inventories 20 active router paths and 25 known Figma variants. Three default routes and two confirmation variants have reviewed captures and Flutter goldens. Seventeen routes and 23 variants remain pending. `dart run tool/report_figma_ui_coverage.dart --strict` is intentionally not passing yet.
- My Data default: Figma node `1948:12072`, 358×68 card/row geometry and route actions checked. Recovery default `1957:11762` and reset complete `1963:11762` were adjusted to source icon/text/button positions. My Data reset confirmation `1977:11817` and recovery reset confirmation `2003:12059` use the shared 277px dialog. Native status bar and home indicator remain outside Flutter widget goldens; minor font rasterization differences remain.
- The shared dialog and action buttons now use the source card width and colors. Buttons are 44px high for the iOS tap-target check; Figma's visible button reference is 43px. A recovery reset failure now clears the busy state and shows an error message.
- Flutter analysis passed, local-only product boundary passed, and all 563 Flutter tests passed with `--coverage --concurrency=1`. Coverage is 83.19% (8460/10169 lines), above CI's 80% minimum. The parallel coverage run stalled in an existing My Page navigation test; its isolated rerun passed. The single-concurrency full run completed normally. Goldens were generated and visually inspected.

## Native test constraint

An iPhone 16 iOS 18 simulator was booted, but `flutter run --no-resident` failed twice while Xcode reported `No space left on device`. The host had 116 MiB free initially; generated Xcode/VSCode/Playwright caches were removed, reaching about 1.6 GiB free, but the build again filled the volume. Only generated files from the failed build were removed; the simulator was shut down. Do not report an iOS app launch, permissions flow, screenshot, or performance result from this checkpoint. A later attempt needs several GiB of free space without erasing user simulator data or device support files.

## Next work

1. Capture deterministic Flutter fixtures for pending Home, My Page, Calendar, and remaining routes. The Figma Home and Calendar references use a 2024-12-21 fixture; app logic treats that date as past now, so use an injectable clock/fixture before approving those views. Source PNGs for these three paths are saved and hash-checked in the manifest.
2. Review the pending My Data password, freshness, busy, snackbar, and restore-preview states. Add behavior and accessibility checks for keyboard, validation, export/restore and reset failures. Review Home loading/error and Calendar expanded/list/swipe/delete/loading/error states.
3. Add iOS integration scenarios for schedule create/edit/delete, backup/restore/reset, recovery and permissions once the simulator build is possible. Profile scrolling/navigation on an attached iPhone. Do not infer native correctness from widget goldens.
4. Re-run `flutter analyze --no-pub`, `flutter test --no-pub --concurrency=1`, `dart run tool/check_local_only_boundary.dart`, and `dart run tool/report_figma_ui_coverage.dart`. Complete strict coverage only after each design route and variant is genuinely reviewed or explicitly excluded with a reason.
