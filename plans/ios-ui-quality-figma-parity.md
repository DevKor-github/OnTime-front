# iOS UI quality and Figma parity

Implementation basis: the current `main` at `c7184b2a`, merged into the isolated QA branch at `64bc111d`. Figma source: `FIdR6bUMHScn9FWbwqrBsA`, page `1:25`, board `285:5`. Korean iOS 390×844 is the reference viewport.

1. Inventory active app screens and Figma variants; record node IDs, route, test fixture, reference image, and documented exceptions. Hidden historical login/account nodes are excluded.
2. Build deterministic widget fixtures with the app's Pretendard font, frozen data/time, explicit viewport and text scale. Compare curated Flutter goldens and targeted geometry assertions with Figma exports. Keep design exports separate from Flutter goldens.
3. Repair visible deviations in shared tokens/components before individual screens. Preserve local-only persistence, backup semantics, alarm behavior, and accessible tap/semantics surfaces.
4. Add widget behavior and accessibility checks, then iOS integration scenarios for creation/edit/delete, backup/restore/reset, recovery, keyboard, and permissions. Profile scrolling and navigation on an attached iPhone.
5. Run analyzer, full tests, static boundary check, golden suite, and simulator flow. Report exact Figma coverage and unexecuted native/physical-device checks; do not claim completion from a passing golden alone.

## Execution checkpoint (2026-09-24)

- Pulled and merged the refreshed `main` screen set (`c7184b2a`) and resolved its UI compile conflicts. The Figma inventory currently reports 21 routes: four defaults reviewed, five in progress, seven pending, five excluded; variants: 11 reviewed, 10 in progress, 22 pending. The manifest and `dart run tool/report_figma_ui_coverage.dart` are the coverage source.
- Compared the new My Page recurring-entry frame with a deterministic Flutter golden. The Figma SVG icons, section spacing, real settings/use-case values, OS notification switch, route links, and accessible tap surfaces are covered. The bottom bar adapts to large text.
- Compared the recurring management list (two active, one ended) and empty frame with new Flutter goldens. Kept the upstream detail, edit, create, and end-series behavior. Narrow-width and enlarged-text states are exercised.
- Added Calendar loading/error full-screen fixtures and goldens, including card/button geometry, blocked interactions, and retry behavior. The default/empty Calendar screen and Home states remain in progress because Figma titles its month December 2024 while drawing November 2024 dates; runtime keeps correct dates.
- Updated recovery, reset confirmation, reset completion, privacy, and My Data dialog goldens to the refreshed `main` widgets. Fresh Figma v3 exports expose visible icon, spacing, and wording differences; their manifest entries are in progress rather than marked visually complete. The reset-complete action still explains the required app restart after storage closure.
- Launched the app in an iOS simulator and exercised Home → My Page → recurring management → series detail → back. This is a native smoke test, not a full permissions, backup/restore, reset, performance, or physical-device check.
- Static analysis, Figma manifest validation, the local-only boundary check, and all 648 Flutter tests pass. The CI coverage checker reports 86.08% (11370/13209 app-owned lines; minimum 80%).
