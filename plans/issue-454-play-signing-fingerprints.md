# Issue 454 Play Signing Fingerprints Plan

Parent track: #467
Sub-issue: #454 - Verify Play App Signing and certificate fingerprints

## Current Status

#454 is externally blocked. The repo can prepare the release-owner checklist,
but Codex cannot complete the acceptance criteria without Play Console,
Firebase console, provider console access, and the finalized Play App Signing
state.

## Blockers

- Play App Signing must be active or the first-upload setup path must be
  confirmed in Play Console.
- The release owner must confirm the upload key used by local and CI signing.
- Firebase console access is required to add release SHA-1 and SHA-256
  fingerprints to the Android app for `club.devkor.ontime`.
- Google Sign-In, Kakao, and any backend allowlists require owner access to
  verify release package and fingerprint settings.

## Repo-Side Work

- Add a secret-free checklist for collecting Play app signing and upload key
  certificate fingerprints.
- Include an evidence template that can be pasted into the issue or secure
  release record.
- Link the checklist from existing Android release configuration and signing
  docs.

## Verification

- `git diff --check`
- `rg -n "Android Play Signing Fingerprints|Play app signing|SHA-256|#454" docs plans`

## Explicitly Left Out

- Recording real fingerprints before Play Console setup is complete.
- Updating Firebase or provider console settings without account access.
- Creating or exposing keystores, passwords, service-account JSON, or
  `google-services.json`.
- Claiming #454 is complete before the release owner records the final values.
