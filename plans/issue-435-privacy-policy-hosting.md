# Issue 435 Privacy Policy Hosting Plan

Parent track: #464
Sub-issue: #435 - Host the privacy policy on a public HTTPS URL

## Decision

#435 cannot be completed in this repository right now because prerequisite #434
is still open and there is no approved privacy policy text to publish. Publishing
also requires access to the chosen public hosting surface.

The repo-side work that legitimately advances #435 is to provide the release
owner with a hosting checklist and evidence form, then link it from release
documentation.

## Blockers

- #434 must provide product/legal-approved privacy policy text.
- A human release owner must choose or confirm the hosting surface.
- A human with hosting access must publish the page at the final public HTTPS
  URL.

## Implementation

1. Add `docs/Privacy-Policy-Hosting.md` with the hosting requirements,
   validation checklist, and final URL evidence form.
2. Link the document from `docs/Home.md`.
3. Reference the document from `docs/Release-Checklist.md` so release owners do
   not miss the privacy policy URL gate.

## Verification

- Run markdown/link-oriented checks only; no app code should change.
- Do not run Flutter tests unless app code changes.

## Out Of Scope

- Drafting or approving the privacy policy text for #434.
- Publishing a website or changing hosting infrastructure.
- Adding the in-app link for #436.
- Entering the URL in Play Console for #437.
