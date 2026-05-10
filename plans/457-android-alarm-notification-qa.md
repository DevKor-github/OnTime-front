# Issue 457 Android Alarm And Notification QA Plan

Issue: #457 - [Release] QA alarm and notification flows on Android
Parent track: #465 - Android permissions and alarm policy

## Current Decision

Issue #457 remains externally blocked. Do not claim closure until a human can run
the Android device QA against a signed release AAB or release-equivalent install.

Repo-side work that can legitimately advance the issue now:

- Provide a scoped Android alarm and notification QA runbook.
- Provide an evidence template that maps directly to #457 acceptance criteria.
- Link the runbook from the release checklist so the manual release flow can find
  it.

Repo-side work that should not be done for #457 now:

- Do not mark #457 complete without device evidence.
- Do not fake signed release, Play Console, backend, or device verification.
- Do not change alarm product behavior unless QA finds a reproducible repo bug.

## Prerequisite State

- #442 is closed by PR #470. Android manifest permissions were audited.
- #443 is closed by PR #469. Notification permission UX was verified and tested.
- #444 is closed by PR #472. Exact alarm permission UX was improved and tested.
- #452 is still open and blocked. A signed release AAB or release-equivalent
  install path is still required for this issue.
- #445 is still open/manual in the parent track order. Play Console full-screen
  intent declaration work requires human account access.

## Plan

1. Add `docs/Android-Alarm-Notification-QA.md` with prerequisites, device matrix,
   permission-state setup commands, QA scenarios, and evidence fields.
2. Link the runbook from `docs/Release-Checklist.md`.
3. Verify documentation formatting and confirm the git diff is limited to #457
   artifacts.
4. Commit the docs-only change with a Conventional Commit referencing #457.
5. Open a draft PR that advances #457 but clearly states the remaining human QA
   and external blockers.

## Human Completion Criteria

The release owner or QA tester must attach evidence for:

- Notification permission granted and denied states.
- Exact alarm permission granted and denied states.
- Native alarm firing, full-screen alarm UI, fallback notification behavior, and
  cancellation.
- Boot restore after device restart where practical.
- Device model, Android version, install artifact, backend environment, account,
  schedule IDs, expected alarm times, results, and failures.
