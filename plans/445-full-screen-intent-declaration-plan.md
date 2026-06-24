# Issue #445 Full-Screen Intent Compliance Plan

Parent track: #465

## Decision

Superseded by Google Play rejection for version code 52. Do not submit another
`USE_FULL_SCREEN_INTENT` declaration for the same app scope. The compliance path
is to remove the permission and API usage, then upload a replacement bundle that
deactivates the rejected version code in every affected Play track.

## Scope

- Confirm the app no longer declares `USE_FULL_SCREEN_INTENT`.
- Confirm the app no longer calls `Notification.Builder.setFullScreenIntent`.
- Document the replacement Play Console remediation path.
- Record QA checks for the remaining alarm notification tap-through behavior.

## Out Of Scope

- Play Console upload/submission.
- Closing #445 without account access and reviewer evidence.
- Final Android alarm/notification QA for #457.
- Changes to unrelated release-track issues.

## Implementation Steps

1. Inspect parent issue #465 and sub-issue state.
2. Inspect #445 prerequisites, labels, and acceptance criteria.
3. Remove `USE_FULL_SCREEN_INTENT` from the release manifest.
4. Remove the native full-screen intent notification builder call.
5. Replace declaration docs with compliance-removal guidance.
6. Build and upload a version code greater than 52 through the approved release
   workflow.

## Verification

- Run `flutter analyze` if the checkout can resolve dependencies.
- Run `git diff --check`.
- Play Console verification is complete only after version code 52 is inactive
  and has 0 releases in App bundle explorer.
