# iOS UI quality and Figma parity completion — 2026-09-25

The implemented app's Figma mapping and visual review are complete with documented source/runtime adaptations. Strict coverage has no pending or in-progress app entry. This is distinct from physical-device acceptance and from implementing every design present in Figma. Delivery remains [Draft PR #596](https://github.com/DevKor-github/OnTime-front/pull/596).

The implementation follows refreshed `main` `c7184b2a`, merged into the isolated QA branch at `64bc111d`. The canonical file is [OnTime Design System](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System), not the earlier `GiDCK...` link. The audit includes Screen Shells, Form Flows, Preparation, and Permission Onboarding; it is not limited to board `285:5`.

## Coverage and completion meaning

[The source-to-code manifest](../figma_code_map.yaml) passes strict validation with the following totals:

| App inventory | Total | Reviewed | Excluded | Pending / in progress |
| --- | ---: | ---: | ---: | ---: |
| Route defaults | 21 | 16 | 5 | 0 |
| Variants | 58 | 57 | 1 | 0 |
| Combined app entries | 79 | **73** | 6 | **0** |

The five excluded routes (`/startup`, `/allowAlarm`, `/scheduleStart`, `/earlyLate`, `/moving`) have no corresponding current full-screen reference after the source audit; their behavior remains tested. The excluded variant `246:238` is the native permission alert, whose app-owned rationale is reviewed separately. Excluded means a stated source/platform boundary, not visual approval.

Separately, `design_only_nodes` contains **11 unmapped standalone Schedule Detail designs**: Upcoming, PreparationDue, Preparing, CompletedOnTime, CompletedLate, CompletedUnknown, PastUnrecorded, Loading, Refreshing, NotFound, and Failure. Repository audit found no matching full-screen route/implementation. They are not the expandable Calendar card and are not included among the 73 reviewed app entries. Their exact nodes are recorded in [the Schedule Detail audit](calendar-parity-20260925.md#unmapped-full-schedule-detail-design-audit); implementing that new flow is outside this completed parity pass.

Reviewed entries connect a verified canonical source, an original export/hash, real Flutter components/fixtures, and a reviewed golden or documented component reuse. Goldens are regression evidence. They do not prove literal pixel equality, native alarm delivery, or physical-device performance.

## Applied result

Source assets, panel geometry, actions, selection controls, dialogs and preparation progress were aligned across the current app. The implementation retains the actual four-step appointment flow, date arithmetic, data-derived times/totals, explicit conflict exclusion, series-owned preparation, scope-aware edits, live timer state, and confirmation before destructive changes. Source inconsistencies and platform boundaries are explicitly documented instead of copied into product behavior.

Independent final review also caught a timer/dialog race: automatic completion could open over a manual finish prompt. A shared dialog guard and current-schedule recheck prevent overlapping prompts, with two real-timer regressions covering completion before and after the user chooses to continue.

The main adaptations are consistent across the reports: bundled Pretendard instead of the source's mixed fonts; native status bars/keyboards/pickers/permissions instead of drawn substitutes; accessible 44px targets and scrolling at large text; correct calendar dates and actual duration sums instead of inconsistent sample artwork; and restart guidance after closed-storage reset. `/scheduleEdit/:scheduleId` shares the creation components and has database-backed edit/override coverage; no separate edit-only source is claimed.

## Evidence index

| Evidence | Scope and interpretation |
| --- | --- |
| [Home and Calendar](calendar-parity-20260925.md) | Default/loading/error, calendar list/expanded/swipe/actions/delete; correct-date exception; 11 unmapped standalone detail designs. |
| [Original forms and preparation edit](original-form-parity-20260925.md) | Name/place inputs, date/time Cupertino pickers, preparation edit, actual totals, save/cancel and enlarged text. |
| [Recurring flows](recurring-parity-20260925.md) | 18 source states, creation/review/conflicts/scope/DST/failure/detail/end, source SHA-to-golden table, actual four-step and edit reuse boundaries. |
| [Onboarding and notification permission](onboarding-parity-20260925.md) | Eleven app-owned states, source artwork, selection/order/numeric entry/validation, focus and OS permission boundary. |
| [Recovery, local data and privacy](recovery-parity-20260925.md) | Recovery/busy/reset, password validation and restore preview, privacy, secure field behavior and closed-storage lifecycle. |
| [Preparation runtime](runtime-parity-20260925.md) | Live on-time/late preparation, restored ring progress, manual finish confirmation, actual state values and narrow/enlarged layouts. |
| [iOS native observations](native-20260925/README.md) | Real simulator setup and permission denial/defer; Files export/import; durable restore/reset/relaunch; device availability and execution limits. |

These reports contain the focused test results and source/Flutter image evidence. Their results support the listed behaviors; the final combined regression result is recorded only below.

## Native data lifecycle demonstrated

The isolated **OnTime Parity Backup QA 20260925** simulator (iPhone17, iOS26.5; UUID `74CFB493-7B8B-4DFD-9DD6-F0E97E682FA7`) completed real numeric three-minute preparation input and saved a local profile with a 30-minute buffer. Actual notification and AlarmKit prompts were denied/deferred through the app's normal controls.

The native Files export saved an **811-byte encrypted backup**. After the buffer was changed to **35 minutes**, selecting the same file decrypted it and produced a restore preview. Confirming restore reloaded the **30-minute buffer** and three-minute preparation. Reset completed, and a full process relaunch returned to Welcome. The external backup survived reset with unchanged SHA-256 `339fe8a981377bdc9ef538e3c08cbb970e73862aff1f2768d2a660eb5814989e`. Screenshots and the exact scope are linked in [the native record](native-20260925/README.md); neither backup bytes nor the QA passphrase are committed.

That run exposed two actual integration defects and verified their repairs: iOS could not use the previous save-location API/type filter, and tapping the native duration row did not reliably focus the intended field. Export now uses the encrypted-file document picker bridge and import supplies a UTI; the row focuses/selects the actual numeric field. Native export cancellation is covered by automated tests, not claimed as an executed cancellation scenario. Successful alarm delivery and a fresh native appointment CRUD pass are not claimed by this data-lifecycle run.

## Final combined validation

<!-- FINAL_VALIDATION_ROOT_START -->
All commands below completed successfully on the final source state, including the two timer/dialog race regressions.

| Validation | Result |
| --- | --- |
| `dart run build_runner build --delete-conflicting-outputs` | Exit 0; ignored generated artifacts regenerated, no generated Dart outputs committed. |
| `flutter analyze --no-pub` | Exit 0; no issues. |
| `flutter test --no-pub --coverage --concurrency=1 --reporter expanded` | Exit 0; **693 passed, 0 failed, 0 skipped**, 4m 29s. This was a comparison run without `--update-goldens`. |
| `dart run tool/check_coverage.dart --min=80` | Exit 0; **87.45% app-owned line coverage (11,969 / 13,686)**, above the 80% threshold. |
| `dart run tool/check_generated_dart_policy.dart` | Exit 0; generated outputs ignored and untracked. |
| `dart run tool/check_local_only_boundary.dart` | Exit 0; local-only boundary verified. |
| `dart run tool/report_figma_ui_coverage.dart --strict` | Exit 0; 73 app entries reviewed, zero pending/in progress, six exclusions; 11 design-only states explicitly separate. |
| `git diff --check` | Exit 0. |
| `flutter build ios --simulator --debug --no-pub` | Exit 0; Xcode build 76.9s, `build/ios/iphonesimulator/Runner.app`. |
| Final simulator install and launch | Exit 0; installed on the isolated QA simulator, launched successfully, and native accessibility read-back showed Welcome, explanatory text and Start. |
| Fresh upstream read | `git fetch origin main` succeeded; `git rev-list --count HEAD..origin/main` returned 0 before the delivery commit. |

The coverage percentage uses the repository's app-owned LCOV filter, excluding generated/localization/schema files; it is not a claim that every source line or device behavior was executed. Remote CI is a separate receipt on Draft PR #596 and must be read against its current head commit.

### Reproducible golden environment

The first remote run on Ubuntu, [36079080226](https://github.com/DevKor-github/OnTime-front/actions/runs/36079080226), passed 632 tests and failed 61 golden comparisons. Every reported failure was a pixel mismatch; there were no non-golden failures. The reviewed images were generated on macOS 26.5.1 with Flutter 3.44.4. Cross-platform font rendering is not guaranteed to match, as described in [Flutter's comparator documentation](https://api.flutter.dev/flutter/flutter_test/GoldenFileComparator-class.html).

The full CI job now runs on the supported [macOS 26 arm64 runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), with Flutter 3.44.4 retained and Homebrew SQLite/libsodium dependencies. It still executes every test and the unchanged exact-pixel comparator, without skipping tests, increasing tolerances or updating goldens in CI. Failure PNGs are uploaded for review. Generate and compare these iOS-first goldens on this macOS/Flutter environment; an OS/SDK rendering change requires explicit image review. The current PR check is the authoritative remote result.
<!-- FINAL_VALIDATION_ROOT_END -->

## Physical-device release gate

`xcrun devicectl list devices` reported the paired iPhones/iPad unavailable. There is no physical-device success claim. Before device acceptance, verify font/layout on an attached iPhone, VoiceOver operation, background and locked-screen alarm delivery, and scrolling/frame-time performance. Simulator debugging and widget semantics checks cannot substitute for those observations.

Draft PR #596 remains the review artifact. Source review, automated regression, the demonstrated native data flow, physical-device acceptance, PR review, merge and release are separate evidence boundaries. [The plan](../../../plans/ios-ui-quality-figma-parity.md) and [handoff](../../../handoff/ios-ui-quality-figma-parity.md) point to this report as the sole final combined-validation receipt.
