# Handoff: Issue #436 Privacy Policy Link

## Current Status

Issue #436 remains externally blocked. No app code was changed because the final
hosted privacy policy URL does not exist in the issue context yet.

## Blockers

- #439 must confirm backend deletion and retention behavior.
- #434 must produce approved privacy policy text using that backend truth.
- #435 must host the approved policy at a public HTTPS URL and record that URL.

## Prepared Repo Artifact

`plans/436-privacy-policy-link-plan.md` documents the exact implementation path,
affected files, verification, and acceptance evidence needed once #435 is done.

## Human Tasks Remaining

1. Complete #439 with backend owner confirmation of account/data deletion and
   retention behavior.
2. Complete #434 with product/legal approval of the final privacy policy text.
3. Complete #435 by hosting that approved policy at a public HTTPS URL that does
   not require login and is not a PDF.
4. Re-run #436 implementation using the final URL from #435.
5. Verify the link in an Android release-equivalent build.
