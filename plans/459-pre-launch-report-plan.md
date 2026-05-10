# Issue 459 Pre-Launch Report Plan

Issue: #459 - Run Play Console pre-launch report and resolve blockers
Parent track: #467 - Android release build and Play setup

## Current Decision

#459 is externally blocked, not repo-solvable, until a signed Android App Bundle
has been uploaded to a Google Play internal or closed testing track. The direct
prerequisite #452 is still open, and #452 also depends on #453 versioning.

Codex cannot run the Play Console pre-launch report without Play Console access
and an uploaded release artifact. The useful repo-side work is to provide a
repeatable release-owner runbook and evidence template for the report.

## Scope

- Add documentation for running the Play Console pre-launch report.
- Define the evidence to record before closing #459.
- Define release-blocking triage expectations for crashes, ANRs, policy
  warnings, and severe accessibility findings.
- Keep signed AAB production, Play upload, device smoke testing, and actual
  report execution out of scope.

## Implementation Steps

1. Add `docs/Play-Pre-Launch-Report.md`.
2. Link the new runbook from `docs/Home.md`.
3. Add a release-checklist pointer for the Play pre-launch report gate.
4. Verify documentation changes with `git diff --check`.

## Human Tasks Remaining

- Complete #453 and #452 so a signed release AAB exists and is uploaded to
  internal or closed testing.
- Use Play Console access to run or wait for the pre-launch report for the
  uploaded build.
- Record report evidence using the template in the runbook.
- Fix release-blocking app findings in follow-up issues or explicitly accept
  non-blocking findings as the release owner.
