# Issue 437 Play Console Privacy Policy URL Plan

Parent track: #464
Sub-issue: #437

## Scope

Complete only the Google Play Console privacy policy URL entry for OnTime after
the final hosted privacy policy URL exists. This issue does not draft, approve,
host, or add the in-app privacy policy link.

## Current Decision

Issue #437 is externally blocked. The prerequisite issue #435 is still open, so
there is no final public HTTPS privacy policy URL to enter. The actual Play
Console field update also requires a human release owner with Play Console
access.

Repo-side implementation should stop at a checklist and evidence template that
helps the release owner complete and prove the console update later.

## Preconditions

1. #435 is complete and has recorded the final public HTTPS privacy policy URL.
2. #436 has either been completed or the release owner has the exact in-app URL
   planned for #436, because #437 requires the Play Console URL to match the
   in-app URL.
3. The release owner has Google Play Console access for package
   `club.devkor.ontime`.

## Human Execution Plan

1. Open Play Console for the OnTime app.
2. Go to the App content page under Policy and programs.
3. Open the privacy policy section.
4. Paste the final HTTPS privacy policy URL from #435.
5. Save the change and resolve any Play Console validation warning.
6. Compare the saved Play Console URL with the in-app URL from #436.
7. Capture a screenshot or release note proving the saved field value.
8. Record the evidence in `handoff/issue_437_play_console_privacy_policy_url.md`
   or the release tracker.

## Verification

- The saved Play Console privacy policy value is an active public HTTPS URL.
- The URL does not require login and is not publicly editable.
- The URL matches the in-app privacy policy link exactly after redirects are
  considered.
- Evidence includes the URL, check date, release owner, and screenshot or
  release-note location.

## References

- Google Play User Data policy:
  https://support.google.com/googleplay/android-developer/answer/10144311
- Google Play app review preparation:
  https://support.google.com/googleplay/android-developer/answer/9859455
