# Issue 456 Android Release Smoke Test Plan

## Scope

Issue #456 is limited to proving that a signed Android release build works on a
real Android device before Play review. The required flow covers install, first
launch, login, logout, schedule create/edit/delete, My Page, privacy policy
link, approved release API endpoint verification, and recording device/build
evidence.

## Current Decision

The issue remains externally blocked. The direct prerequisite, #452, is open and
blocked until #453 locks production versioning. Without a signed release AAB or
release-equivalent install path, a real Android device, release API/backend
visibility, and Play/internal-testing access, this thread cannot honestly
complete the smoke test.

## Repo-Side Action

Add a release smoke-test runbook and evidence template so the human tester can
complete #456 as soon as #452 produces the signed build. Keep implementation to
documentation; do not alter app behavior or release workflows for this issue.

## Human Completion Steps

1. Complete #453 and then #452 so a signed installable Android release build is
   available.
2. Install the build through Play Internal Testing or another approved
   release-equivalent path.
3. Run `docs/Android-Release-Smoke-Test.md` on a real Android device.
4. Record device, Android version, version name, version code, install source,
   endpoint evidence, and pass/fail results on #456.
5. Open follow-up bugs for any failed smoke-test row before Play review.
