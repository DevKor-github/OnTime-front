# Issue 458 Account Deletion End-to-End QA Plan

Parent track: #464
Sub-issue: #458 - QA account deletion end to end

## Current Status

Externally blocked. Do not run or claim completion for this QA until the
blocking prerequisites are complete:

- #438 is closed by PR #471. The in-app account deletion flow has repo-side
  coverage for discoverability, cancellation, loading, failure, success, and
  provider routing.
- #439 is open and manual. A backend owner must verify account and data deletion
  behavior for the release-supported auth providers and document any retained
  data.
- #452 is open and blocked. QA requires a signed release build or
  release-equivalent install path.

## Scope

Verify the complete account deletion outcome from a release-equivalent app
install through backend state, session invalidation, local app recovery, and
evidence recording.

This issue does not change app behavior. It records the QA procedure and the
evidence needed once backend and release-build prerequisites are available.

## Required Inputs

- Release-equivalent Android install source, artifact path, version name, and
  version code from #452.
- Backend deletion truth from #439, including which data types are deleted,
  retained, retention reasons, and verification method.
- Test user credentials for each release-supported provider:
  - Normal account, if enabled in the release build.
  - Google account, if enabled in the release build.
  - Apple account, if enabled in the release build.
- Backend owner or environment access that can verify post-deletion user,
  schedule, preparation, token/session, and provider-link records.
- Privacy policy or data-retention text that the backend owner confirms matches
  observed deletion behavior.

## Test Matrix

Run each applicable provider path independently. Do not reuse a deleted account.

| Provider path | Test account | In release build? | Backend verification owner | Result |
| --- | --- | --- | --- | --- |
| Normal account | TBD | TBD | TBD | Not run |
| Google | TBD | TBD | TBD | Not run |
| Apple | TBD | TBD | TBD | Not run |

Skip a provider only when it is unavailable in the release build, and record the
reason.

## Pre-Test Setup

For each test account:

1. Install the release-equivalent build from the #452 artifact or approved
   release-equivalent path.
2. Sign in with the provider under test.
3. Create or confirm at least one schedule tied to the account.
4. Confirm My Page shows the account/settings area and the delete-account entry.
5. Capture the pre-delete backend state for:
   - User account record.
   - Auth provider link or social account record.
   - Access/refresh token or session records, if persisted server-side.
   - Schedules.
   - Preparations/default preparation.
   - Alarm settings/device/alarm status records, if applicable.
   - Feedback/deletion reason record, if applicable.

## Happy-Path QA Steps

For each provider path:

1. Open My Page and tap the delete-account entry.
2. Confirm that the first dialog communicates account deletion and has a cancel
   path.
3. Continue to the feedback dialog.
4. Submit deletion with a unique feedback value:
   `Issue 458 QA <provider> <YYYY-MM-DD HH:mm KST>`.
5. Confirm the dialog enters a loading state and cannot be dismissed while the
   request is in flight.
6. Confirm successful deletion returns the app to the signed-out or sign-in
   state.
7. Restart the app and confirm the deleted credentials/session cannot continue
   into the app.
8. Attempt sign-in with the same credentials and record the actual behavior:
   blocked, new account created, provider re-consent required, or other.
9. Ask the backend owner to verify post-delete state against #439's documented
   policy.
10. Record screenshots, logs, backend evidence, and final pass/fail status.

## Failure-Handling QA Steps

Run at least one controlled failure case before final sign-off, using a method
approved by the backend or release owner:

1. Make the deletion request fail without deleting the account, such as with a
   blocked network, test backend error response, or revoked test token.
2. Tap delete account and submit the feedback dialog.
3. Confirm the app shows a recoverable error.
4. Confirm the user remains signed in and the dialog recovers from loading.
5. Confirm backend state was not partially deleted.
6. Restore normal connectivity/backend behavior and complete the happy path.

## Evidence Form

Complete this form for each provider path.

```text
Issue: #458
Parent track: #464
Provider path:
Tester:
Date/time and timezone:
Build source:
Artifact path:
Version name/code:
Device model:
OS version:
Backend environment:
Test account identifier:

Pre-delete account state:
Pre-delete schedule/preparation state:
Feedback value submitted:
App result after deletion:
App restart/session result:
Re-sign-in result:
Backend post-delete user state:
Backend post-delete schedule/preparation state:
Backend retained data and reason:
Privacy policy match confirmed by:
Failure-handling result:

Screenshots/log links:
Backend evidence links:
Final result: PASS / FAIL / BLOCKED
Notes:
```

## Pass Criteria

#458 can be closed only when all applicable provider paths satisfy the
acceptance criteria:

- Account deletion succeeds for a test user.
- Deleted credentials or sessions cannot continue using the app.
- Associated schedule/user data is removed or retained exactly as documented by
  #439 and the privacy policy.
- Failure handling is recoverable and does not leave the app or backend in a
  partially broken state.
- Test results and evidence are recorded.

## Stop Conditions

Stop and leave #458 open if any of these occur:

- #439 has not documented backend deletion and retention behavior.
- #452 has not produced a release build or approved release-equivalent install
  path.
- The backend owner cannot verify post-delete records.
- The observed backend behavior differs from the privacy policy or #439 output.
- A provider path available in the release build cannot be tested.

## Next Action

Complete #439 first, then #452. Once both are available, run this plan and paste
the completed evidence forms into #458 or the release QA record.
