# Issue 462 Reusable Release Checklist Plan

## Status

Issue #462 is blocked by prerequisite release issues #450-#459. The reusable
checklist can be drafted now, but final issue closure should wait until the
signed AAB, Play Console, Android device QA, account deletion QA, and pre-launch
report results have settled.

## Parent Track Context

Parent issue #468 orders the work as:

1. #461 Play review rejection response playbook - closed.
2. #463 release ownership and rollout monitoring checklist - closed.
3. #462 reusable app release checklist - currently blocked.

## Decision

Advance #462 by making `docs/Release-Checklist.md` the central reusable release
checklist and linking it from `docs/Home.md`. Keep the checklist explicitly
marked as draft/source material until the remaining #450-#459 prerequisites are
resolved.

## Checklist Scope

The checklist must cover:

- Generated files and generated-file drift review.
- `flutter pub get`.
- `dart run build_runner build --delete-conflicting-outputs`.
- `flutter analyze`.
- `flutter test`.
- `flutter build appbundle --release`.
- Version bump and Android version code rules.
- Release signing and Firebase configuration.
- Signed Android App Bundle build evidence.
- Store metadata, screenshots, Play declarations, Data safety, and privacy
  policy review triggers.
- Android device QA, alarm and notification QA, account deletion QA, Play
  pre-launch report review, and rollout monitoring handoff.

## Remaining Human Tasks

- Complete or close the open prerequisite issues in #450-#459.
- Reconcile the checklist against the final signed AAB build path, workflow run,
  Play App Signing fingerprints, Play Console developer verification state, QA
  evidence, and pre-launch report outcome.
- Remove or update the draft-status note only when #462 is ready for final
  closure.
