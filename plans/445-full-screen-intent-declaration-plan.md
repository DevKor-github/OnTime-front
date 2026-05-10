# Issue #445 Full-Screen Intent Declaration Plan

Parent track: #465

## Decision

Prepare Play Console review material for `USE_FULL_SCREEN_INTENT`, but do not
claim issue completion from the repo. The issue remains manually blocked until a
human with Play Console access submits the declaration and QA records device
evidence.

## Scope

- Confirm the app uses full-screen intent only for user-scheduled
  alarm/reminder moments.
- Document why OnTime qualifies as an alarm/reminder use case.
- Prepare Play Console declaration wording and reviewer evidence.
- Record QA checks needed to prove the full-screen UI is not used for
  promotional, generic, or low-priority notifications.

## Out Of Scope

- Play Console submission.
- Closing #445 without account access and reviewer evidence.
- Final Android alarm/notification QA for #457.
- Changes to unrelated release-track issues.

## Implementation Steps

1. Inspect parent issue #465 and sub-issue state.
2. Inspect #445 prerequisites, labels, and acceptance criteria.
3. Verify merged context from #442, #443, and #444.
4. Inspect Android manifest, native alarm receiver/activity, notification
   suppression, and alarm reconciliation code.
5. Add a release document containing declaration copy, source evidence, and
   human QA/submission checklist.
6. Link the document from the release checklist.

## Verification

- Run `flutter analyze` if the checkout can resolve dependencies.
- Run `git diff --check`.
- No device or Play Console verification can be completed by Codex for this
  manual issue.

