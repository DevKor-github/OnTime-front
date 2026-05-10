# Issue 455 Plan: Android Developer Verification

## Scope

Issue #455 is limited to checking and recording Play Console developer
verification and package-name registration status for `club.devkor.ontime`.

## Decision

This issue cannot be fully solved from the repository because it requires
Google Play Console access and, possibly, release signing ownership. The useful
repo-side work is to give the Play Console owner a concrete checklist and a
safe status template that avoids storing sensitive identity or signing data in
git.

## Steps

1. Confirm the parent release track order and blockers.
2. Confirm issue #455 labels and acceptance criteria.
3. Add release documentation for Play developer verification and package-name
   registration.
4. Link the documentation from the release checklist.
5. Leave the actual Play Console identity verification, package-name
   registration, and status recording to the human account owner.

## External Tasks

- Check Play Console developer identity verification status.
- Confirm whether `club.devkor.ontime` was automatically registered.
- Register the package/signing key if Play Console requires manual
  registration.
- Record the non-sensitive result and any deadline in the release issue or
  secure release account record.
