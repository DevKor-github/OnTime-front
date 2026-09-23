# iOS UI quality and Figma parity

Implementation basis: committed `feature/figma-offline-screen-sync` at `44067d7a` in an isolated worktree. Figma source: `FIdR6bUMHScn9FWbwqrBsA`, page `1:25`, board `285:5`. Korean iOS 390×844 is the reference viewport.

1. Inventory active app screens and Figma variants; record node IDs, route, test fixture, reference image, and documented exceptions. Hidden historical login/account nodes are excluded.
2. Build deterministic widget fixtures with the app's Pretendard font, frozen data/time, explicit viewport and text scale. Compare curated Flutter goldens and targeted geometry assertions with Figma exports. Keep design exports separate from Flutter goldens.
3. Repair visible deviations in shared tokens/components before individual screens. Preserve local-only persistence, backup semantics, alarm behavior, and accessible tap/semantics surfaces.
4. Add widget behavior and accessibility checks, then iOS integration scenarios for creation/edit/delete, backup/restore/reset, recovery, keyboard, and permissions. Profile scrolling and navigation on an attached iPhone.
5. Run analyzer, full tests, static boundary check, golden suite, and simulator flow. Report exact Figma coverage and unexecuted native/physical-device checks; do not claim completion from a passing golden alone.

## Execution checkpoint (2026-09-23)

- Created a route and variant inventory with hash-verified Figma images. Four route defaults and two confirmation variants are visually reviewed; 16 route defaults and 23 variants remain pending. The manifest and `dart run tool/report_figma_ui_coverage.dart` are the current coverage source.
- Built deterministic 390×844 widget fixtures for My Data, local-data recovery, and reset completion. Tests cover Figma geometry, goldens, reset cancellation, retry, 2× text, and iOS touch target guidance. The shared confirmation dialog now has a 277px card, Figma action colors, and 44px touch targets.
- Matched the My Page section grid and 24px selection controls to Figma, including the bottom navigation button position. A Korean 390×844 golden and iOS touch/semantics checks cover the default state.
- `flutter analyze --no-pub`, the local-only boundary check, and 564 Flutter tests with coverage (single-concurrency run) passed. Coverage is 83.95% against the CI minimum of 80%. The iOS simulator build was attempted twice and failed because the host disk ran out of space; no native launch or physical-device profile is claimed.
- A separate handoff note in `handoff/ios-ui-quality-figma-parity.md` records the remaining work and build constraint.
