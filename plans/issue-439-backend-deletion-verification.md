# Issue 439 Backend Deletion Verification Plan

Issue: #439, parent track #464
Status: externally blocked by backend owner or environment access
Date: 2026-05-10

## Goal

Verify that backend account deletion removes or retains OnTime user data exactly
as the release privacy policy will describe.

## Current Repo Facts

- The release track orders #439 immediately after #438.
- #438 is closed by PR #471, which verified the in-app deletion UX.
- PR #378 routes deletion requests through the release client endpoints and
  includes tests for optional feedback payloads and auth-provider routing.
- The client deletion endpoints currently used by the app are:
  - Normal account: `DELETE /users/me/delete`
  - Google account: `DELETE /oauth2/google/me`
  - Apple account: `DELETE /oauth2/apple/me`
- The app checks `GET /users/me` for `socialType` before choosing the deletion
  endpoint.

These facts verify client behavior only. They do not verify server-side data
deletion, third-party token revocation, audit logging, backups, or retention.

## Decision-Complete Plan

1. Backend owner identifies every persisted data category tied to a user in the
   release backend, including user profile, auth identity, tokens, devices, FCM
   tokens, alarm settings, default preparations, schedules, schedule
   preparations, feedback, deletion feedback, logs, analytics, and backups.
2. Backend owner runs deletion for each auth provider supported in the release
   build: normal, Google, and Apple. Do not test or document Kakao unless it is
   enabled in the release build.
3. For each provider, backend owner records the deletion endpoint called,
   environment, account identifier, timestamp, response, and post-deletion
   database/API evidence.
4. For each data category, backend owner records whether it is deleted,
   anonymized, retained, or not applicable, plus the retention reason and
   duration when retained.
5. Product or privacy owner compares the verified backend behavior with the
   privacy policy draft before approving #434.
6. If backend behavior and policy text diverge, fix the backend or update the
   policy before closing #439.
7. Once verified, use the #439 evidence to unblock #441 Data safety and #458
   account deletion end-to-end QA.

## Acceptance Mapping

- Backend behavior verified for each release auth provider: requires backend
  owner evidence for normal, Google, and Apple accounts.
- Associated user data deletion confirmed by data type: use the evidence matrix
  in `handoff/issue-439-backend-deletion-verification.md`.
- Retained data and retention reason documented: use the retention columns in
  the handoff matrix.
- Privacy policy text matches backend behavior: complete only after #434 has a
  policy draft and owner review against this evidence.

## Exit Criteria

#439 can be closed only after a backend owner or environment operator provides
the completed evidence matrix and a product/privacy owner confirms that the
privacy policy text matches the verified behavior.
