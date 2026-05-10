# Issue 439 Backend Deletion Verification Handoff

Issue: #439, parent track #464
Branch: `codexd/439-backend-deletion-verification`
Status: externally blocked
Date: 2026-05-10

## Summary

Repo-side review found no frontend code change that can honestly complete #439.
The release client already routes account deletion by provider, and the remaining
acceptance criteria require backend owner confirmation of real server-side
deletion and retention behavior.

Use this document as the evidence form for the backend owner, privacy owner, and
release QA owner. Treat all filled-in values as release evidence.

## Repo-Side Evidence Already Available

- Normal account deletion uses `DELETE /users/me/delete`.
- Google account deletion uses `DELETE /oauth2/google/me`.
- Apple account deletion uses `DELETE /oauth2/apple/me`.
- Optional deletion feedback is sent in the deletion request body when present.
- The app chooses the endpoint from `GET /users/me` `socialType`.
- PR #378 added deletion endpoint routing and tests.
- PR #471 verified in-app deletion UX and success/failure behavior.

## Backend Verification Prerequisites

- Backend owner or environment operator with access to the release backend data
  store.
- Test accounts for every auth provider enabled in the release build:
  - Normal account
  - Google account
  - Apple account
- Agreement on the environment to verify, for example staging release candidate
  or production-equivalent backend.
- Privacy/product owner available to compare the verified behavior against the
  privacy policy draft.

## Provider Evidence

Fill one row per auth provider that is enabled in the release build. Do not add
Kakao unless it is active in the release build.

| Provider | Endpoint Called | Environment | Test Account ID | Request Time | Response | Re-login Fails? | Owner | Evidence Link |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Normal | `DELETE /users/me/delete` | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Google | `DELETE /oauth2/google/me` | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Apple | `DELETE /oauth2/apple/me` | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

## Data Deletion and Retention Matrix

Backend owner must replace `TBD` values with verified behavior. If a row is not
part of the backend data model, mark it `N/A` and explain why.

| Data Category | Backend Location | Deleted, Anonymized, Retained, or N/A | Retention Duration | Retention Reason | Verification Method | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| User profile fields such as email, name, and social identity | TBD | TBD | TBD | TBD | TBD | TBD |
| Password or auth credentials for normal accounts | TBD | TBD | TBD | TBD | TBD | TBD |
| OAuth provider linkage or revoke state for Google | TBD | TBD | TBD | TBD | TBD | TBD |
| OAuth provider linkage or revoke state for Apple | TBD | TBD | TBD | TBD | TBD | TBD |
| Access and refresh tokens | TBD | TBD | TBD | TBD | TBD | TBD |
| Device records and FCM tokens | TBD | TBD | TBD | TBD | TBD | TBD |
| Alarm settings and alarm status | TBD | TBD | TBD | TBD | TBD | TBD |
| Default preparation settings | TBD | TBD | TBD | TBD | TBD | TBD |
| Schedules | TBD | TBD | TBD | TBD | TBD | TBD |
| Schedule preparation steps | TBD | TBD | TBD | TBD | TBD | TBD |
| Spare time setting | TBD | TBD | TBD | TBD | TBD | TBD |
| General feedback sent through `/feedback` | TBD | TBD | TBD | TBD | TBD | TBD |
| Account deletion feedback sent in delete request body | TBD | TBD | TBD | TBD | TBD | TBD |
| Operational logs, audit logs, crash logs, analytics, or monitoring events | TBD | TBD | TBD | TBD | TBD | TBD |
| Backups or disaster recovery snapshots | TBD | TBD | TBD | TBD | TBD | TBD |

## Privacy Policy Cross-Check

Before closing #439, confirm the privacy policy draft states:

- Which account and app data is deleted after account deletion.
- Which data is retained, why it is retained, and for how long.
- Whether deletion feedback or support messages may be retained.
- Whether logs or backups retain account-related data temporarily.
- Which auth providers are supported in the release build.

## Exact Remaining Human Tasks

- Backend owner completes the provider evidence table.
- Backend owner completes the data deletion and retention matrix.
- Privacy/product owner reconciles the completed evidence with the privacy
  policy draft for #434.
- Release owner updates #439 with the completed evidence and decides whether the
  backend behavior satisfies the acceptance criteria.
