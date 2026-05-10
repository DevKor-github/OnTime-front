# Issue 434 Privacy Policy Draft Plan

Parent track: #464 Privacy, account deletion, and Data safety
Issue: #434 [Release] Draft and approve the privacy policy
Status: advanced, externally blocked for final approval

## Decision

Create a repo-owned privacy policy draft that product/legal owners can review,
edit, approve, and publish after backend deletion behavior is verified in #439.
Do not claim the policy is final because #439 is still open and the developer
legal entity, contact method, hosting URL, and retention exceptions require
human confirmation.

## Inputs Reviewed

- #464 ordered privacy/account-deletion track.
- #434 scope, labels, prerequisites, and acceptance criteria.
- #438 status and merged PR #471, confirming the in-app account deletion flow
  was verified from the frontend side.
- #439 status, confirming backend deletion and retention behavior still needs
  backend-owner verification.
- App-owned data flows in `lib/data/data_sources/`,
  `lib/core/constants/endpoint.dart`, local Drift tables, notification/alarm
  services, Android manifest permissions, and existing release docs.
- Google Play Help guidance for privacy policies, account deletion, and Data
  safety declarations.

## Repo Work

1. Add `docs/Privacy-Policy-Draft.md`.
2. Include the policy title, draft status, approval blockers, data inventory,
   third-party processors, security handling, retention/deletion placeholders,
   and a publish-readiness checklist.
3. Link the draft from `docs/Home.md` so release owners can find it.

## Human Tasks Before Closing #434

1. Backend owner verifies #439 and supplies exact deletion behavior by data
   type, including any retained data and retention period/reason.
2. Product/legal owner confirms the developer/entity name shown in the Google
   Play listing.
3. Product/legal owner supplies the privacy contact method.
4. Product/legal owner reviews and approves the final policy text.
5. Release owner hands the approved text to #435 for public HTTPS hosting.
