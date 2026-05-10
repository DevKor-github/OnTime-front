# Issue 437 Handoff: Play Console Privacy Policy URL

Parent track: #464
Sub-issue: #437
Prepared: 2026-05-10

## Status

Externally blocked. Do not close #437 until the final hosted privacy policy URL
from #435 is entered in Google Play Console and evidence is recorded.

## Blockers

- #435 is still open; the final public HTTPS privacy policy URL is not available
  in this repo.
- Play Console entry requires a human release owner with access to the OnTime
  Google Play Console app.
- The saved Play Console URL must match the in-app privacy policy URL required
  by #436.

## Required Field Value

- Package name: `club.devkor.ontime`
- Privacy policy URL: `<paste final #435 HTTPS URL here>`
- In-app privacy policy URL to compare against: `<paste final #436 URL here>`

## Completion Checklist

- [ ] Confirm #435 is closed and records the final hosted privacy policy URL.
- [ ] Confirm the URL opens over HTTPS without login.
- [ ] Confirm the URL is an HTML/web page, not a PDF, and is not publicly
      editable.
- [ ] Confirm the URL names OnTime or the same developer/entity used in the
      Google Play listing.
- [ ] Enter the URL in Play Console under the app content privacy policy field.
- [ ] Save the Play Console change without validation errors.
- [ ] Confirm the saved Play Console URL matches the in-app URL from #436.
- [ ] Capture screenshot or release note evidence showing the completed field.
- [ ] Update #437 with the evidence location and close it.

## Evidence Record

Fill this in after the manual console update.

```text
Release owner:
Checked date:
Play Console app/package: club.devkor.ontime
Final privacy policy URL:
Matching in-app URL:
Evidence screenshot or release note:
Notes:
```

## References

- Google Play User Data policy:
  https://support.google.com/googleplay/android-developer/answer/10144311
- Google Play app review preparation:
  https://support.google.com/googleplay/android-developer/answer/9859455
